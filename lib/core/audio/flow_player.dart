import 'dart:async';

import 'package:just_audio/just_audio.dart' as ja;

/// Estado simplificado del reproductor que consume la interfaz.
enum PlayerState { stopped, playing, paused, completed }

/// Cada cuanto se publica la posicion a la interfaz.
///
/// Cuatro veces por segundo basta para la barra de progreso y evita redibujar
/// el reproductor en cada fotograma.
const Duration positionUpdateInterval = Duration(milliseconds: 250);

/// Vista del reproductor de `just_audio` que usa la interfaz.
///
/// Expone solo lo que necesitan las pantallas (estado, posicion, duracion y
/// controles basicos). La carga de fuentes y la cola nativa del autoplay
/// quedan en `FlowAudioHandler`.
class FlowPlayer {
  FlowPlayer(this._player);

  final ja.AudioPlayer _player;

  PlayerState get state => _mapState(_player.playerState);

  Stream<PlayerState> get onPlayerStateChanged =>
      _player.playerStateStream.map(_mapState).distinct();

  Stream<Duration> get onPositionChanged => _player.createPositionStream(
    minPeriod: positionUpdateInterval,
    maxPeriod: positionUpdateInterval,
  );

  Stream<Duration> get onDurationChanged => _player.durationStream
      .where((duration) => duration != null && duration > Duration.zero)
      .map((duration) => duration!);

  Stream<void> get onPlayerComplete => _player.processingStateStream
      .where((state) => state == ja.ProcessingState.completed)
      .map((_) {});

  double get volume => _player.volume;
  double get playbackRate => _player.speed;

  Future<Duration?> getDuration() async => _player.duration;
  Future<Duration?> getCurrentPosition() async => _player.position;

  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> pause() => _player.pause();

  /// `just_audio` completa `play()` cuando la reproduccion se detiene, no
  /// cuando empieza; por eso no se espera.
  Future<void> resume() async {
    unawaited(_player.play());
  }

  Future<void> stop() => _player.stop();
  Future<void> setVolume(double volume) => _player.setVolume(volume);
  Future<void> setPlaybackRate(double rate) => _player.setSpeed(rate);

  static PlayerState _mapState(ja.PlayerState state) {
    return switch (state.processingState) {
      ja.ProcessingState.idle => PlayerState.stopped,
      ja.ProcessingState.completed => PlayerState.completed,
      _ => state.playing ? PlayerState.playing : PlayerState.paused,
    };
  }
}
