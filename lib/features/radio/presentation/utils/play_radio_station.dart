import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/audio/background_audio_handler.dart';
import 'package:flow_music/core/engagement/review_prompt_coordinator.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/history/presentation/controllers/playback_history_controller.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/data/repositories/radio_browser_repository.dart';
import 'package:flow_music/features/radio/data/station_removals_repository.dart';
import 'package:flow_music/features/radio/presentation/controllers/radio_queue_controller.dart';
import 'package:flow_music/features/radio/presentation/utils/playback_retry.dart';
import 'package:flow_music/features/radio/presentation/utils/playback_retry_feedback.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

int _latestPlaybackRequest = 0;

/// Resolves and starts a station immediately when the user selects it.
///
/// Success means the native player confirmed [PlayerState.playing]. A failed
/// first attempt is reported and retried automatically once. After the second
/// failure, the user gets a SnackBar action to start a fresh retry cycle.
Future<bool> playRadioStation({
  required BuildContext context,
  required WidgetRef ref,
  required RadioStation station,
  List<RadioStation>? queue,
  int? index,
  RadioBrowserRepository? repository,
}) async {
  if (!station.isPlayable) return false;
  final requestId = ++_latestPlaybackRequest;
  final removals =
      await (repository?.removalsRepository ??
              StationRemovalsRepository.instance)
          .load();
  if (!context.mounted || requestId != _latestPlaybackRequest) return false;
  if (removals.contains(station)) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(LocaleKeys.station_unavailable.tr())),
    );
    return false;
  }
  if (queue != null && index != null) {
    ref.read(radioQueueControllerProvider.notifier).enqueue(queue, index);
  }

  return _resolveAndPlay(
    context: context,
    ref: ref,
    station: station,
    requestId: requestId,
    repository: repository,
  );
}

/// Advances to the next queued station and starts it automatically.
Future<bool> playNextRadioStation({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final next = ref.read(radioQueueControllerProvider.notifier).next();
  if (next == null) return false;
  return playRadioStation(context: context, ref: ref, station: next);
}

/// Goes back to the previous queued station and starts it automatically.
Future<bool> playPreviousRadioStation({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final previous = ref.read(radioQueueControllerProvider.notifier).previous();
  if (previous == null) return false;
  return playRadioStation(context: context, ref: ref, station: previous);
}

Future<bool> _resolveAndPlay({
  required BuildContext context,
  required WidgetRef ref,
  required RadioStation station,
  required int requestId,
  RadioBrowserRepository? repository,
}) async {
  final ownsRepository = repository == null;
  final activeRepository = repository ?? RadioBrowserRepository();
  final stationId = station.stationUuid.isEmpty
      ? station.streamUrl
      : station.stationUuid;
  final artUrl = station.artworkUrl.isEmpty ? null : station.artworkUrl;
  final artist = [
    if (station.country.isNotEmpty) station.country,
    if (station.codec.isNotEmpty) station.codec,
    if (station.bitrate > 0) '${station.bitrate} kbps',
  ].join(' · ');
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
  automaticRetryNotice;

  bool isCurrentRequest() => requestId == _latestPlaybackRequest;

  try {
    flowAudioHandler.beginMediaPreparation(
      id: stationId,
      title: station.name,
      artist: artist,
      artUrl: artUrl,
    );
    var streamUrl = await activeRepository.countClickAndResolveUrl(station);
    if (!isCurrentRequest()) return false;
    _debugLogRadioStream(station, streamUrl);
    Object? finalPlaybackFailure;

    Future<void> playResolvedStream() {
      return flowAudioHandler.playUrl(
        url: streamUrl,
        id: stationId,
        title: station.name,
        artist: artist,
        artUrl: artUrl,
      );
    }

    // Artwork loading must never delay or prevent audio playback. The shared
    // CachedNetworkImage handles visual failures independently.
    final succeeded = await runPlaybackWithAutomaticRetry(
      shouldContinue: isCurrentRequest,
      attempt: () async {
        if (!isCurrentRequest()) throw const _PlaybackSuperseded();
        await playResolvedStream();
      },
      retryAttempt: () async {
        if (!isCurrentRequest()) throw const _PlaybackSuperseded();
        streamUrl = await activeRepository.refreshResolvedUrl(
          station,
          fallbackUrl: streamUrl,
        );
        if (!isCurrentRequest()) throw const _PlaybackSuperseded();
        _debugLogRadioStream(station, streamUrl, isRetry: true);
        await playResolvedStream();
      },
      onAutomaticRetry: (error) {
        debugPrint('Radio playback failed; retrying automatically: $error');
        flowAudioHandler.continueMediaPreparation();
        if (!context.mounted || !isCurrentRequest()) return;
        final messenger = ScaffoldMessenger.maybeOf(context);
        automaticRetryNotice = showAutomaticPlaybackRetryNotice(messenger);
      },
      onFinalFailure: (error) {
        finalPlaybackFailure = error;
        debugPrint('Radio playback failed after automatic retry: $error');
        automaticRetryNotice?.close();
        if (!context.mounted || !isCurrentRequest()) return;
        final messenger = ScaffoldMessenger.maybeOf(context);
        showFinalPlaybackFailureNotice(
          messenger,
          onRetry: () {
            if (!context.mounted) return;
            unawaited(
              playRadioStation(
                context: context,
                ref: ref,
                station: station,
                repository: repository,
              ),
            );
          },
        );
      },
    );

    if (!succeeded || !isCurrentRequest()) {
      if (isCurrentRequest() && finalPlaybackFailure != null) {
        await activeRepository.healthRepository.recordFailure(
          station,
          finalPlaybackFailure,
        );
      }
      return false;
    }
    automaticRetryNotice?.close();
    await activeRepository.healthRepository.recordSuccess(station);

    try {
      await ref
          .read(playbackHistoryControllerProvider.notifier)
          .recordRadio(
            stationId: station.stationUuid.isEmpty
                ? station.streamUrl
                : station.stationUuid,
            name: station.name,
            country: station.country,
            artworkUrl: artUrl ?? '',
            stationData: station.rawData,
          );
    } catch (error) {
      // Persistence should never turn successful audio into a playback error.
      debugPrint('Unable to record radio playback history: $error');
    }

    unawaited(
      ref
          .read(reviewPromptCoordinatorProvider)
          .recordSuccessfulPlay(
            stationId: station.stationUuid,
            countryCode: station.countryCode,
            source: 'selection',
          ),
    );

    return true;
  } catch (error) {
    if (!context.mounted || !isCurrentRequest()) return false;
    if (error is StationUnavailableException) {
      flowAudioHandler.failMediaPreparation(error);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(LocaleKeys.station_unavailable.tr())),
      );
      return false;
    }
    debugPrint('Unable to resolve radio stream: $error');
    await activeRepository.healthRepository.recordFailure(station, error);
    if (!context.mounted || !isCurrentRequest()) return false;
    flowAudioHandler.failMediaPreparation(error);
    final messenger = ScaffoldMessenger.maybeOf(context);
    showFinalPlaybackFailureNotice(
      messenger,
      onRetry: () {
        if (!context.mounted) return;
        unawaited(
          playRadioStation(
            context: context,
            ref: ref,
            station: station,
            repository: repository,
          ),
        );
      },
    );
    return false;
  } finally {
    automaticRetryNotice?.close();
    if (ownsRepository) activeRepository.close();
  }
}

class _PlaybackSuperseded implements Exception {
  const _PlaybackSuperseded();
}

void _debugLogRadioStream(
  RadioStation station,
  String streamUrl, {
  bool isRetry = false,
}) {
  if (!kDebugMode) return;
  final phase = isRetry ? 'retry' : 'selected';
  debugPrint('[Radio][$phase] ${station.name}: $streamUrl');
}
