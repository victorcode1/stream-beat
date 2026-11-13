import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/audio/background_audio_handler.dart';
import 'package:flow_music/core/audio/remote_audio_proxy_stub.dart'
    if (dart.library.io) 'package:flow_music/core/audio/remote_audio_proxy_io.dart';
import 'package:flow_music/core/routes/app_navigator_key.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/core/utils/main_controller.dart';
import 'package:flow_music/features/autoplay/data/audio_cache_stub.dart'
    if (dart.library.io) 'package:flow_music/features/autoplay/data/audio_cache_io.dart';
import 'package:flow_music/features/autoplay/data/shared_youtube_client.dart';
import 'package:flow_music/features/autoplay/presentation/controllers/autoplay_queue_controller.dart';
import 'package:flow_music/features/autoplay/presentation/controllers/cache_status_controller.dart';
import 'package:flow_music/features/home/data/location_service.dart';
import 'package:flow_music/features/home/presentation/controllers/home_view_controller.dart';
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
  bool _wasInBackground = false;
  final List<ProviderSubscription<Object?>> _subscriptions = [];
  late final MonetizationCoordinator _monetizationCoordinator = ref.read(
    monetizationCoordinatorProvider,
  );

  void initialize() {
    flowAudioHandler.onTrackComplete = handleTrackComplete;
    ref.read(songController).onVideoComplete = handleTrackComplete;
    flowAudioHandler.onSkipToNext = handleSkipToNext;
    flowAudioHandler.onSkipToPrevious = handleSkipToPrevious;
    flowAudioHandler.prepareNextTrack = _prepareNextTrack;
    flowAudioHandler.onAutoAdvanced = _handleAutoAdvanced;
    _watchNativeQueueInputs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_promptCountryLocationAccessIfNeeded());
    });
    unawaited(_monetizationCoordinator.initialize());
  }

  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.close();
    }
    _subscriptions.clear();
    flowAudioHandler.prepareNextTrack = null;
    flowAudioHandler.onAutoAdvanced = null;
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

  /// Mantiene la pista encolada en el reproductor nativo alineada con la
  /// cola de autoplay y con los ajustes de repetir y autoplay.
  void _watchNativeQueueInputs() {
    unawaited(
      flowAudioHandler.setRepeatCurrent(ref.read(repeatModeControllerProvider)),
    );
    _subscriptions
      ..add(
        ref.listen<bool>(repeatModeControllerProvider, (_, repeat) {
          unawaited(flowAudioHandler.setRepeatCurrent(repeat));
        }),
      )
      ..add(
        ref.listen<String?>(
          songController.select((controller) => controller.currentVideoId),
          (_, videoId) {
            if (videoId == null) return;
            ref.read(homeViewProvider.notifier).followPlayingSong(videoId);
          },
        ),
      )
      ..add(
        ref.listen<bool>(autoplayEnabledControllerProvider, (_, _) {
          unawaited(flowAudioHandler.refreshQueuedNext());
        }),
      )
      ..add(
        ref.listen<String?>(
          autoplayQueueControllerProvider.select(
            (queue) => queue.upcoming.firstOrNull?.videoId,
          ),
          (_, nextId) {
            if (flowAudioHandler.queuedNextId == nextId) return;
            unawaited(flowAudioHandler.refreshQueuedNext());
          },
        ),
      );
  }

  /// Siguiente pista del autoplay para la playlist nativa, o `null` si la
  /// pista actual no viene de la cola (radio, video, repetir, autoplay off).
  Future<QueuedTrack?> _prepareNextTrack(String currentId) async {
    if (!ref.read(autoplayEnabledControllerProvider)) return null;
    if (ref.read(repeatModeControllerProvider)) return null;
    final controller = ref.read(songController);
    if (controller.currentMode != PlaybackMode.audio) return null;
    if (controller.currentVideoId != currentId) return null;
    final queue = ref.read(autoplayQueueControllerProvider);
    if (queue.current?.videoId != currentId) return null;

    final next = await ref
        .read(autoplayQueueControllerProvider.notifier)
        .peekNextResolved();
    if (next == null) return null;
    if (ref.read(songController).currentVideoId != currentId) return null;
    return controller.queuedTrackFor(next);
  }

  /// El reproductor nativo paso solo a [id]: avanza la cola y la cancion
  /// actual sin volver a cargar el audio.
  Future<void> _handleAutoAdvanced(String id) async {
    final queue = ref.read(autoplayQueueControllerProvider);
    NextTrack? track;
    if (queue.upcoming.firstOrNull?.videoId == id) {
      track = await ref
          .read(autoplayQueueControllerProvider.notifier)
          .playNext();
      if (track?.suggestion.videoId != id) track = null;
    }
    ref.read(songController).adoptNativeAdvance(id: id, track: track);
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
        unawaited(clearAudioCache());
      case AppLifecycleState.resumed:
        if (_wasInBackground) {
          _wasInBackground = false;
          _refreshNetworkConnections();
        }
        unawaited(_promptCountryLocationAccessIfNeeded());
      case AppLifecycleState.paused:
        _wasInBackground = true;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// Al volver de segundo plano, las conexiones guardadas con YouTube y
  /// googlevideo pueden estar cortadas; reutilizarlas hacia que la siguiente
  /// cancion no sonara.
  void _refreshNetworkConnections() {
    refreshSharedYoutubeExplode();
    refreshRemoteAudioConnections();
  }

  void handleCacheStatusChanged(CacheStatus? previous, CacheStatus next) {
    if (!next.shouldShowDialog) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDiskFullDialog();
    });
  }

  /// Canciones seguidas que se pueden saltar si no suenan, antes de rendirse.
  static const _maxSkippedTracks = 3;

  Future<void> _playQueueTrack(NextTrack? next, {PlaybackMode? mode}) async {
    final controller = ref.read(songController);
    final queue = ref.read(autoplayQueueControllerProvider.notifier);
    var track = next;
    for (var attempt = 0; track != null; attempt++) {
      await _playTrack(controller, track, mode: mode);
      // Una cancion que YouTube no entrega no debe detener el autoplay.
      if (!controller.playbackFailed || attempt >= _maxSkippedTracks) return;
      debugPrint('Skipping ${track.suggestion.videoId}: playback failed');
      track = await queue.playNext();
    }
  }

  Future<void> _playTrack(
    SongController controller,
    NextTrack next, {
    PlaybackMode? mode,
  }) async {
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
