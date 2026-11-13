import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flow_music/core/audio/background_audio_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import 'modern_player_view_state.dart';

/// Controller de presentacion del reproductor moderno.
///
/// Centraliza listeners, timers, comandos de audio/video y el estado derivado
/// que la vista necesita para renderizarse.
class ModernPlayerViewController extends ValueNotifier<ModernPlayerViewState> {
  final FlowPlayer audioPlayer;

  VideoPlayerController? _videoController;
  String? _currentVideoId;
  double _playbackRate;
  bool _normalizeVolume;

  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<MediaItem?>? _mediaItemSubscription;
  String? _mediaItemId;
  Timer? _videoUpdateTimer;
  bool _isDisposed = false;

  ModernPlayerViewController({
    required this.audioPlayer,
    VideoPlayerController? videoController,
    String? currentVideoId,
    double playbackRate = 1,
    bool normalizeVolume = false,
  }) : _videoController = videoController,
       _currentVideoId = currentVideoId,
       _playbackRate = playbackRate,
       _normalizeVolume = normalizeVolume,
       super(const ModernPlayerViewState()) {
    _initialize();
  }

  void syncWith({
    required VideoPlayerController? videoController,
    required String? currentVideoId,
    required double playbackRate,
    required bool normalizeVolume,
  }) {
    if (!identical(_videoController, videoController)) {
      _videoController = videoController;
      _initVideoListeners();
    }

    if (_currentVideoId != currentVideoId) {
      _currentVideoId = currentVideoId;
      _resetTrackProgress();
      _restoreTrackProgress();
    }

    if (_playbackRate != playbackRate) {
      _playbackRate = playbackRate;
      _applyPlaybackRate(playbackRate);
    }

    if (_normalizeVolume != normalizeVolume) {
      _normalizeVolume = normalizeVolume;
      _applyVolume(value.volume);
    }
  }

  void togglePlayPause() {
    final videoController = _videoController;
    if (videoController != null && videoController.value.isInitialized) {
      if (value.isPlaying) {
        videoController.pause();
      } else {
        videoController.play();
      }
      return;
    }

    if (value.isPlaying) {
      audioPlayer.pause();
    } else {
      audioPlayer.resume();
    }
  }

  void seekTo(Duration position) {
    final videoController = _videoController;
    if (videoController != null && videoController.value.isInitialized) {
      videoController.seekTo(position);
    } else {
      audioPlayer.seek(position);
    }
  }

  void skip(int seconds) {
    final newPosition = value.position + Duration(seconds: seconds);
    if (newPosition >= Duration.zero &&
        newPosition <= value.effectiveDuration) {
      seekTo(newPosition);
    }
  }

  void toggleMute() {
    final nextMuted = !value.isMuted;
    _emit(value.copyWith(isMuted: nextMuted));
    if (nextMuted) {
      final videoController = _videoController;
      if (videoController != null) {
        videoController.setVolume(0);
      } else {
        audioPlayer.setVolume(0);
      }
      return;
    }
    _applyVolume(value.volume);
  }

  void setVolume(double volume) {
    _emit(value.copyWith(volume: volume, isMuted: false));
    _applyVolume(volume);
  }

  Future<void> _initialize() async {
    _applyPlaybackRate(_playbackRate);
    _applyVolume(value.volume);

    audioPlayer.getDuration().then((duration) {
      if (duration != null) {
        _emit(value.copyWith(duration: duration));
      }
    });

    audioPlayer.getCurrentPosition().then((position) {
      if (position != null) {
        _emit(value.copyWith(position: _clampPosition(position)));
      }
    });

    _durationSubscription = audioPlayer.onDurationChanged.listen((duration) {
      if (value.trustedDuration != null &&
          value.trustedDuration! > Duration.zero) {
        return;
      }
      _emit(value.copyWith(duration: duration));
    }, onError: (Object _, StackTrace _) {});

    _positionSubscription = audioPlayer.onPositionChanged.listen((position) {
      _emit(value.copyWith(position: _clampPosition(position)));
    });

    _mediaItemId = flowAudioHandler.mediaItem.value?.id;
    _mediaItemSubscription = flowAudioHandler.mediaItem.listen((item) {
      final nextId = item?.id;
      if (nextId != _mediaItemId) {
        _mediaItemId = nextId;
        _resetTrackProgress();
      }
      final duration = item?.duration;
      if (duration != null && duration > Duration.zero) {
        _emit(
          value.copyWith(
            trustedDuration: duration,
            position: _clampPosition(value.position),
          ),
        );
      } else {
        _emit(value.copyWith(trustedDuration: null));
      }
    });

    final initialTrustedDuration = flowAudioHandler.mediaItem.value?.duration;
    if (initialTrustedDuration != null &&
        initialTrustedDuration > Duration.zero) {
      _emit(value.copyWith(trustedDuration: initialTrustedDuration));
    }

    _playerStateSubscription = audioPlayer.onPlayerStateChanged.listen((state) {
      _emit(value.copyWith(isPlaying: state == PlayerState.playing));
    });

    _emit(value.copyWith(isPlaying: audioPlayer.state == PlayerState.playing));
    _initVideoListeners();
  }

  void _initVideoListeners() {
    _videoUpdateTimer?.cancel();

    final videoController = _videoController;
    if (videoController == null) {
      return;
    }

    _videoUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!videoController.value.isInitialized) {
        return;
      }
      _emit(
        value.copyWith(
          duration: videoController.value.duration,
          position: _clampPosition(videoController.value.position),
          isPlaying: videoController.value.isPlaying,
        ),
      );
    });
  }

  Future<void> _applyPlaybackRate(double rate) async {
    final safeRate = rate.clamp(0.5, 2.0).toDouble();
    try {
      final videoController = _videoController;
      if (videoController != null) {
        await videoController.setPlaybackSpeed(safeRate);
      } else {
        await audioPlayer.setPlaybackRate(safeRate);
      }
    } catch (_) {}
  }

  void _applyVolume(double volume) {
    final effectiveVolume = _normalizeVolume
        ? volume.clamp(0.0, 0.86).toDouble()
        : volume;
    final videoController = _videoController;
    if (videoController != null) {
      videoController.setVolume(effectiveVolume);
    } else {
      audioPlayer.setVolume(effectiveVolume);
    }
  }

  Duration _clampPosition(Duration position) {
    if (position < Duration.zero) {
      return Duration.zero;
    }

    final limit = value.effectiveDuration;
    if (limit > Duration.zero && position > limit) {
      return limit;
    }
    return position;
  }

  /// Vuelve a leer la duracion y la posicion de la pista que ya suena.
  ///
  /// Si el autoplay cambio de cancion en segundo plano, la duracion llego
  /// mientras la pantalla no se redibujaba. Al volver, este sync ve el id nuevo
  /// y reinicia el progreso; sin releerlo, la barra quedaba en 00:00 y no
  /// permitia adelantar.
  void _restoreTrackProgress() {
    final item = flowAudioHandler.mediaItem.value;
    final trusted = item?.duration;
    if (item != null &&
        item.id == _currentVideoId &&
        trusted != null &&
        trusted > Duration.zero) {
      _emit(value.copyWith(trustedDuration: trusted));
    }
    audioPlayer.getDuration().then((duration) {
      if (duration != null && duration > Duration.zero) {
        _emit(value.copyWith(duration: duration));
      }
    });
    audioPlayer.getCurrentPosition().then((position) {
      if (position != null) {
        _emit(value.copyWith(position: _clampPosition(position)));
      }
    });
  }

  void _resetTrackProgress() {
    _emit(
      value.copyWith(
        duration: Duration.zero,
        trustedDuration: null,
        position: Duration.zero,
      ),
    );
  }

  void _emit(ModernPlayerViewState nextState) {
    if (_isDisposed) {
      return;
    }
    value = nextState;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _mediaItemSubscription?.cancel();
    _videoUpdateTimer?.cancel();
    super.dispose();
  }
}
