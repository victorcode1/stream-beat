import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/audio/background_audio_handler.dart';
import 'package:flow_music/core/routes/app_navigator_key.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/core/utils/main_controller.dart';
import 'package:flow_music/features/autoplay/data/audio_cache_stub.dart'
    if (dart.library.io) 'package:flow_music/features/autoplay/data/audio_cache_io.dart';
import 'package:flow_music/features/autoplay/presentation/controllers/autoplay_queue_controller.dart';
import 'package:flow_music/features/autoplay/presentation/controllers/cache_status_controller.dart';
import 'package:flow_music/features/home/data/location_service.dart';
import 'package:flow_music/features/monetization/application/monetization_coordinator.dart';
import 'package:flow_music/features/monetization/application/monetization_coordinator_provider.dart';
import 'package:flow_music/features/settings/presentation/controllers/autoplay_enabled_controller.dart';
import 'package:flow_music/features/song/presentation/controllers/repeat_mode_controller.dart';
import 'package:flow_music/features/song/presentation/controllers/song_controller.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final mainAppControllerProvider = Provider<MainAppController>(
  MainAppController.new,
);

class MainAppController {
  MainAppController(this.ref);

  final Ref ref;
  DateTime? _lastLocationPromptAt;
  late final MonetizationCoordinator _monetizationCoordinator = ref.read(
    monetizationCoordinatorProvider,
  );

  void initialize() {
    flowAudioHandler.onTrackComplete = handleTrackComplete;
    ref.read(songController).onVideoComplete = handleTrackComplete;
    flowAudioHandler.onSkipToNext = handleSkipToNext;
    flowAudioHandler.onSkipToPrevious = handleSkipToPrevious;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_promptCountryLocationAccessIfNeeded());
    });
    unawaited(_monetizationCoordinator.initialize());
  }

  void dispose() {
    _monetizationCoordinator.dispose();
    final controller = ref.read(songController);
    if (controller.onVideoComplete == handleTrackComplete) {
      controller.onVideoComplete = null;
    }
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

  Future<void> handleTrackComplete() async {
    final controller = ref.read(songController);
    final completedMode = controller.currentMode;
    if (ref.read(repeatModeControllerProvider)) {
      if (completedMode == PlaybackMode.video) {
        await controller.replayCurrentVideo();
        return;
      }
      final player = flowAudioHandler.player;
      await player.seek(Duration.zero);
      await player.resume();
      return;
    }

    if (!ref.read(autoplayEnabledControllerProvider)) return;
    final next = await ref
        .read(autoplayQueueControllerProvider.notifier)
        .playNext();
    await _playQueueTrack(next, mode: completedMode);
  }

  Future<void> handleSkipToNext() async {
    final next = await ref
        .read(autoplayQueueControllerProvider.notifier)
        .playNext();
    await _playQueueTrack(next);
  }

  Future<void> handleSkipToPrevious() async {
    final previous = ref
        .read(autoplayQueueControllerProvider.notifier)
        .playPrevious();
    if (previous == null) {
      await flowAudioHandler.seek(Duration.zero);
      return;
    }
    await _playQueueTrack(previous);
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
        ref.read(mainController).setAudioStateDetached();
        unawaited(clearAudioCache());
      case AppLifecycleState.resumed:
        ref.read(mainController).setAudioStateResumed();
        unawaited(_promptCountryLocationAccessIfNeeded());
        break;
      case AppLifecycleState.inactive:
        ref.read(mainController).setAudioStateInactive();
        break;
      case AppLifecycleState.paused:
        ref.read(mainController).setAudioStatePaused();
        break;
      case AppLifecycleState.hidden:
        ref.read(mainController).setAudioStateHidden();
        break;
    }
  }

  void handleCacheStatusChanged(CacheStatus? previous, CacheStatus next) {
    if (!next.shouldShowDialog) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDiskFullDialog();
    });
  }

  Future<void> _playQueueTrack(NextTrack? next, {PlaybackMode? mode}) async {
    if (next == null) return;
    final controller = ref.read(songController);
    if ((mode ?? controller.currentMode) == PlaybackMode.video) {
      await controller.playVideo(id: next.suggestion.videoId);
      return;
    }
    final resolved = next.resolved;
    if (resolved != null) {
      await controller.playPrefetched(resolved);
      return;
    }
    await controller.playAudio(id: next.suggestion.videoId);
  }

  void _showDiskFullDialog() {
    final status = ref.read(cacheStatusControllerProvider);
    if (!status.shouldShowDialog) return;

    final navigatorContext = _navigatorDialogContext;
    if (navigatorContext == null) return;

    ref.read(cacheStatusControllerProvider.notifier).acknowledge();
    showDialog<void>(
      context: navigatorContext,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.sd_card_alert_rounded),
          title: Text(LocaleKeys.storage_full_title.tr()),
          content: Text(LocaleKeys.storage_full_message.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(LocaleKeys.understood.tr()),
            ),
          ],
        );
      },
    );
  }

  // Location is used only while the app is open to choose country-based
  // recommendations. Coordinates are never stored or sent to a backend.
  Future<void> _promptCountryLocationAccessIfNeeded() async {
    final lastPromptAt = _lastLocationPromptAt;
    if (lastPromptAt != null &&
        DateTime.now().difference(lastPromptAt) < const Duration(minutes: 10)) {
      return;
    }

    const locationService = LocationService();
    final status = await locationService.locationAccessStatus();
    if (status == LocationAccessStatus.available ||
        status == LocationAccessStatus.webUnsupported) {
      return;
    }

    final messenger = ref.read(mainController).scaffoldMessage.currentState;
    if (messenger == null) return;
    _lastLocationPromptAt = DateTime.now();

    final message = switch (status) {
      LocationAccessStatus.serviceDisabled =>
        'Activa la ubicacion para sugerirte musica popular de tu pais.',
      LocationAccessStatus.permissionDenied =>
        'Permite la ubicacion para sugerirte musica popular de tu pais.',
      LocationAccessStatus.permissionDeniedForever =>
        'Habilita la ubicacion desde ajustes para sugerirte musica por pais.',
      LocationAccessStatus.available ||
      LocationAccessStatus.webUnsupported => '',
    };

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          // Con accion, Flutter deja el aviso fijo hasta que se cierra a mano
          // y tapaba los controles del reproductor. Los exitos ya salen del
          // pais del telefono, asi que basta con mostrarlo unos segundos.
          persist: false,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Ajustes',
            onPressed: () {
              switch (status) {
                case LocationAccessStatus.serviceDisabled:
                  unawaited(locationService.openDeviceLocationSettings());
                case LocationAccessStatus.permissionDenied:
                  unawaited(locationService.requestLocationAccess());
                case LocationAccessStatus.permissionDeniedForever:
                  unawaited(locationService.openAppLocationSettings());
                case LocationAccessStatus.available:
                case LocationAccessStatus.webUnsupported:
                  break;
              }
            },
          ),
        ),
      );
  }

  BuildContext? get _navigatorDialogContext {
    final navigatorKey = ref.read(appNavigatorKeyProvider);
    return navigatorKey.currentContext ?? navigatorKey.currentState?.context;
  }
}
