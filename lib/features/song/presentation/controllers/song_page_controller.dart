import 'package:audio_service/audio_service.dart';
import 'package:flow_music/core/audio/background_audio_handler.dart';
import 'package:flow_music/features/autoplay/presentation/controllers/autoplay_queue_controller.dart';
import 'package:flow_music/features/song/presentation/controllers/song_controller.dart';

class SongPageArgs {
  const SongPageArgs({
    required this.id,
    required this.initialMode,
    required this.initialDuration,
  });

  final String id;
  final PlaybackMode? initialMode;
  final Duration? initialDuration;
}

/// Coordina parseo de argumentos y acciones puntuales de presentacion.
class SongPageController {
  const SongPageController();

  SongPageArgs? resolveArgs({
    required Map<String?, String?> data,
    required SongController controller,
  }) {
    final rawId = data['idSong'];
    if (rawId == null) return null;

    return SongPageArgs(
      id: controller.extractVideoId(rawId) ?? rawId,
      initialMode: playbackModeFromName(data['mediaType']),
      initialDuration: durationFromMilliseconds(data['durationMs']),
    );
  }

  void configurePlaylist({
    required SongController controller,
    required String? playlistId,
  }) {
    controller.playListSong(playListId: playlistId);
  }

  void initializePlayback({
    required SongController controller,
    required String id,
    required PlaybackMode? initialMode,
    PlaybackMode defaultMode = PlaybackMode.audio,
    Duration? initialDuration,
  }) {
    final requestedMode = initialMode ?? defaultMode;
    if (initialMode != PlaybackMode.audio &&
        _hasCurrentVideoPlayback(controller: controller, id: id)) {
      return;
    }

    final playingId = flowAudioHandler.mediaItem.value?.id;
    final processingState =
        flowAudioHandler.playbackState.value.processingState;
    final isLiveOnHandler =
        processingState != AudioProcessingState.idle &&
        processingState != AudioProcessingState.completed;

    if (requestedMode == PlaybackMode.audio &&
        playingId == id &&
        isLiveOnHandler) {
      return;
    }
    // La cancion ya se esta cargando (p. ej. la vista se reconstruyo al
    // seguir al autoplay): pedirla otra vez reiniciaria la carga.
    if (requestedMode == PlaybackMode.audio &&
        controller.isLoading &&
        controller.currentVideoId == id) {
      return;
    }

    switch (requestedMode) {
      case PlaybackMode.audio:
        controller.playAudio(id: id, knownDuration: initialDuration);
      case PlaybackMode.video:
        controller.playVideo(id: id);
    }
  }

  bool _hasCurrentVideoPlayback({
    required SongController controller,
    required String id,
  }) {
    final video = controller.videoPlayerController;
    if (controller.currentVideoId != id ||
        controller.currentMode != PlaybackMode.video ||
        video == null) {
      return false;
    }

    final value = video.value;
    return value.isInitialized && !value.hasError;
  }

  Future<void> playFromQueue({
    required SongController controller,
    required NextTrack? track,
  }) async {
    if (track == null) return;
    if (controller.currentMode == PlaybackMode.video) {
      await controller.playVideo(id: track.suggestion.videoId);
      return;
    }
    final resolved = track.resolved;
    if (resolved != null) {
      await controller.playPrefetched(resolved);
      return;
    }
    await controller.playAudio(id: track.suggestion.videoId);
  }

  PlaybackMode? playbackModeFromName(String? name) {
    return switch (name) {
      'audio' => PlaybackMode.audio,
      'video' => PlaybackMode.video,
      _ => null,
    };
  }

  Duration? durationFromMilliseconds(String? value) {
    if (value == null || value.isEmpty) return null;
    final milliseconds = int.tryParse(value);
    if (milliseconds == null || milliseconds <= 0) return null;
    return Duration(milliseconds: milliseconds);
  }
}
