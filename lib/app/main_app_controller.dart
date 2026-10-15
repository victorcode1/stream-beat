import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/analytics/product_analytics.dart';
import 'package:flow_music/core/audio/background_audio_handler.dart';
import 'package:flow_music/core/engagement/review_prompt_coordinator.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/core/utils/main_controller.dart';
import 'package:flow_music/features/account/application/local_user_data_coordinator.dart';
import 'package:flow_music/features/account/presentation/providers/local_user_data_providers.dart';
import 'package:flow_music/features/history/presentation/controllers/playback_history_controller.dart';
import 'package:flow_music/features/monetization/application/monetization_coordinator.dart';
import 'package:flow_music/features/monetization/application/monetization_coordinator_provider.dart';
import 'package:flow_music/features/monetization/presentation/providers/monetization_providers.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/data/repositories/radio_browser_repository.dart';
import 'package:flow_music/features/radio/data/station_removals_repository.dart';
import 'package:flow_music/features/radio/presentation/controllers/radio_queue_controller.dart';
import 'package:flow_music/features/radio/presentation/utils/playback_retry.dart';
import 'package:flow_music/features/radio/presentation/utils/playback_retry_feedback.dart';
import 'package:flow_music/features/settings/presentation/controllers/autoplay_enabled_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final mainAppControllerProvider = Provider<MainAppController>(
  MainAppController.new,
);

class MainAppController {
  MainAppController(this.ref);

  final Ref ref;
  int _queuePlaybackRequest = 0;
  late final MonetizationCoordinator _monetizationCoordinator = ref.read(
    monetizationCoordinatorProvider,
  );
  late final LocalUserDataCoordinator _localUserDataCoordinator = ref.read(
    localUserDataCoordinatorProvider,
  );

  void initialize() {
    flowAudioHandler.onTrackComplete = handleTrackComplete;
    flowAudioHandler.onSkipToNext = handleSkipToNext;
    flowAudioHandler.onSkipToPrevious = handleSkipToPrevious;
    unawaited(ref.read(productAnalyticsProvider).track('app_open'));
    unawaited(ref.read(reviewPromptCoordinatorProvider).initialize());
    unawaited(_monetizationCoordinator.initialize());
    unawaited(_localUserDataCoordinator.initialize());
  }

  void dispose() {
    _monetizationCoordinator.dispose();
    _localUserDataCoordinator.dispose();
    if (flowAudioHandler.onTrackComplete == handleTrackComplete) {
      flowAudioHandler.onTrackComplete = null;
    }
    if (flowAudioHandler.onSkipToNext == handleSkipToNext) {
      flowAudioHandler.onSkipToNext = null;
    }
    if (flowAudioHandler.onSkipToPrevious == handleSkipToPrevious) {
      flowAudioHandler.onSkipToPrevious = null;
    }
  }

  Future<void> refreshAccount() async {
    try {
      await ref.read(subscriptionRepositoryProvider).refresh();
      await _localUserDataCoordinator.selectCurrentUser();
    } catch (_) {
      // A network failure leaves local changes available for the next resume.
    }
  }

  Future<void> handleTrackComplete() async {
    if (!ref.read(autoplayEnabledControllerProvider)) return;
    await _playQueuedStation(
      ref.read(radioQueueControllerProvider.notifier).next(),
    );
  }

  Future<void> handleSkipToNext() async {
    await _playQueuedStation(
      ref.read(radioQueueControllerProvider.notifier).next(),
    );
  }

  Future<void> handleSkipToPrevious() async {
    final previous = ref.read(radioQueueControllerProvider.notifier).previous();
    if (previous == null) {
      await flowAudioHandler.seek(Duration.zero);
      return;
    }
    await _playQueuedStation(previous);
  }

  Future<void> _playQueuedStation(RadioStation? station) async {
    if (station == null || !station.isPlayable) return;

    final requestId = ++_queuePlaybackRequest;
    final repository = RadioBrowserRepository();
    final stationId = station.stationUuid.isEmpty
        ? station.streamUrl
        : station.stationUuid;
    final artUrl = station.artworkUrl.isEmpty ? null : station.artworkUrl;
    ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
    automaticRetryNotice;
    bool isCurrentRequest() => requestId == _queuePlaybackRequest;

    try {
      final removals = await repository.removalsRepository.load();
      if (!isCurrentRequest()) return;
      if (removals.contains(station)) {
        ref
            .read(mainController)
            .scaffoldMessage
            .currentState
            ?.showSnackBar(
              SnackBar(content: Text(LocaleKeys.station_unavailable.tr())),
            );
        return;
      }
      flowAudioHandler.beginMediaPreparation(
        id: stationId,
        title: station.name,
        artist: station.country,
        artUrl: artUrl,
      );
      var streamUrl = await repository.countClickAndResolveUrl(station);
      if (!isCurrentRequest()) return;
      _debugLogQueuedRadioStream(station, streamUrl);
      final messenger = ref.read(mainController).scaffoldMessage.currentState;
      Object? finalPlaybackFailure;

      Future<void> playResolvedStream() {
        return flowAudioHandler.playUrl(
          url: streamUrl,
          id: stationId,
          title: station.name,
          artist: station.country,
          artUrl: artUrl,
        );
      }

      final succeeded = await runPlaybackWithAutomaticRetry(
        shouldContinue: isCurrentRequest,
        attempt: playResolvedStream,
        retryAttempt: () async {
          if (!isCurrentRequest()) return;
          streamUrl = await repository.refreshResolvedUrl(
            station,
            fallbackUrl: streamUrl,
          );
          if (!isCurrentRequest()) return;
          _debugLogQueuedRadioStream(station, streamUrl, isRetry: true);
          await playResolvedStream();
        },
        onAutomaticRetry: (error) {
          debugPrint('Queued radio playback failed; retrying: $error');
          flowAudioHandler.continueMediaPreparation();
          automaticRetryNotice = showAutomaticPlaybackRetryNotice(messenger);
        },
        onFinalFailure: (error) {
          finalPlaybackFailure = error;
          debugPrint('Queued radio retry failed: $error');
          automaticRetryNotice?.close();
        },
      );

      if (!succeeded || !isCurrentRequest()) {
        if (isCurrentRequest() && finalPlaybackFailure != null) {
          await repository.healthRepository.recordFailure(
            station,
            finalPlaybackFailure,
          );
          final next = ref.read(radioQueueControllerProvider.notifier).next();
          if (next != null) {
            await _playQueuedStation(next);
          } else {
            showFinalPlaybackFailureNotice(
              messenger,
              onRetry: () => unawaited(_playQueuedStation(station)),
            );
          }
        }
        return;
      }
      automaticRetryNotice?.close();
      await repository.healthRepository.recordSuccess(station);
      await ref
          .read(playbackHistoryControllerProvider.notifier)
          .recordRadio(
            stationId: station.stationUuid.isEmpty
                ? station.streamUrl
                : station.stationUuid,
            name: station.name,
            country: station.country,
            artworkUrl: artUrl ?? station.artworkUrl,
            stationData: station.rawData,
          );
      unawaited(
        ref
            .read(reviewPromptCoordinatorProvider)
            .recordSuccessfulPlay(
              stationId: station.stationUuid,
              countryCode: station.countryCode,
              source: 'queue',
            ),
      );
    } catch (error) {
      debugPrint('Unable to advance the radio queue: $error');
      if (isCurrentRequest()) {
        if (error is! StationUnavailableException) {
          await repository.healthRepository.recordFailure(station, error);
        }
        flowAudioHandler.failMediaPreparation(error);
      }
    } finally {
      automaticRetryNotice?.close();
      repository.close();
    }
  }
}

void _debugLogQueuedRadioStream(
  RadioStation station,
  String streamUrl, {
  bool isRetry = false,
}) {
  if (!kDebugMode) return;
  final phase = isRetry ? 'retry' : 'selected';
  debugPrint('[Radio queue][$phase] ${station.name}: $streamUrl');
}
