import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'background_time.dart';
import 'remote_audio_proxy_stub.dart'
    if (dart.library.io) 'remote_audio_proxy_io.dart';

late final FlowAudioHandler flowAudioHandler;

Future<FlowAudioHandler> initFlowAudioHandler() async {
  flowAudioHandler = await AudioService.init(
    builder: FlowAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId:
          'com.victorflores.streambeatmusic.channel.audio',
      androidNotificationChannelName: 'Reproduccion de audio',
      androidNotificationChannelDescription:
          'Controles de reproduccion de StreamBeat',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationClickStartsActivity: true,
      rewindInterval: Duration(seconds: 10),
      fastForwardInterval: Duration(seconds: 10),
    ),
  );

  return flowAudioHandler;
}

/// Cada cuanto se consulta la posicion al reproductor nativo.
///
/// `audioplayers` la consulta por defecto en cada fotograma: hasta 120 llamadas
/// por segundo al canal nativo en pantallas de 120 Hz, que ademas obligan a
/// Flutter a dibujar sin parar y reconstruyen los reproductores en cada una.
/// Cuatro veces por segundo basta para la barra de progreso y el fundido.
const Duration positionUpdateInterval = Duration(milliseconds: 250);

class FlowAudioHandler extends BaseAudioHandler with SeekHandler {
  FlowAudioHandler() {
    player.positionUpdater = TimerPositionUpdater(
      interval: positionUpdateInterval,
      getPosition: player.getCurrentPosition,
    );
    _subscriptions.add(
      player.onPlayerStateChanged.listen((state) {
        _playerState = state;
        // `stop()` forma parte del cambio de fuente. No debe reemplazar el
        // estado `loading` de la pista nueva por un `idle` tardio de la pista
        // anterior.
        if (_isSwitchingSource && state == PlayerState.stopped) return;
        _broadcastPlaybackState();
      }),
    );
    _subscriptions.add(
      player.onPositionChanged.listen((position) {
        if (_isSwitchingSource) return;
        // Si tenemos una duracion confiable (la cabecera del proveedor),
        // recortamos la posicion reportada por audioplayers para que la UI
        // nunca muestre tiempo "vacio" mas alla del final real del audio.
        _position = _hasTrustedDuration && position > _duration
            ? _duration
            : position;
        _maybeStartFadeOut(position);
        // audioplayers sigue reproduciendo (silencio o padding) varios
        // segundos despues del fin canonico, asi que `onPlayerComplete`
        // llega tarde y autoplay se queda esperando. En cuanto la posicion
        // toca la duracion reportada, disparamos el complete nosotros
        // mismos para que la siguiente cancion arranque sin retraso.
        if (!_completionFired &&
            _duration > Duration.zero &&
            position >= _duration) {
          _completionFired = true;
          unawaited(_handleCompletion());
        }
      }),
    );
    _subscriptions.add(
      player.onDurationChanged.listen((duration) {
        // Cuando el caller declara una duracion confiable (p.ej. el
        // metadato canonico de YouTube), ignoramos la duracion reportada
        // por audioplayers porque a veces excede el audio real por unos
        // segundos. Esto evita el "tail" vacio en la barra de progreso.
        if (_hasTrustedDuration) return;
        _applyDuration(duration);
      }, onError: _ignorePlayerStreamError),
    );
    _subscriptions.add(
      player.onPlayerComplete.listen((_) {
        if (_completionFired) return;
        _completionFired = true;
        unawaited(_handleCompletion());
      }, onError: _ignorePlayerStreamError),
    );
  }

  final AudioPlayer player = AudioPlayer();
  final List<StreamSubscription> _subscriptions = [];
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _hasTrustedDuration = false;
  bool _completionFired = false;
  bool _isSwitchingSource = false;

  /// Identifica el cambio de fuente mas reciente. Los preparativos nativos de
  /// una URL pueden terminar fuera de orden cuando el usuario toca varias
  /// canciones rapidamente; solo la solicitud mas nueva puede publicar estado,
  /// iniciar un fade o reportar un error.
  int _sourceGeneration = 0;

  static const Duration _fadeOutDuration = Duration(milliseconds: 2500);
  static const Duration _fadeInDuration = Duration(milliseconds: 700);
  static const Duration _fadeStep = Duration(milliseconds: 50);
  static const Duration _nativeCleanupTimeout = Duration(seconds: 2);
  bool _smoothTransitions = true;
  bool _fadeOutStarted = false;
  int _fadeGeneration = 0;

  void setSmoothTransitions(bool value) {
    _smoothTransitions = value;
    if (!value) {
      _fadeGeneration++;
      _fadeOutStarted = false;
      unawaited(player.setVolume(1));
    }
  }

  void _maybeStartFadeOut(Duration position) {
    if (!_smoothTransitions || _fadeOutStarted) return;
    if (!_hasTrustedDuration || _duration <= _fadeOutDuration) return;
    final remaining = _duration - position;
    if (remaining <= _fadeOutDuration && remaining > Duration.zero) {
      _fadeOutStarted = true;
      unawaited(_runFade(from: 1, to: 0, total: remaining));
    }
  }

  Future<void> _runFade({
    required double from,
    required double to,
    required Duration total,
  }) async {
    final generation = ++_fadeGeneration;
    final steps = (total.inMilliseconds / _fadeStep.inMilliseconds)
        .floor()
        .clamp(1, 1000);
    await player.setVolume(from);
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(_fadeStep);
      if (generation != _fadeGeneration) return;
      final volume = (from + (to - from) * (i / steps)).clamp(0.0, 1.0);
      await player.setVolume(volume);
    }
  }

  /// Hook fired when the current track finishes naturally. The app wires this
  /// to the autoplay queue so the next prefetched suggestion plays.
  Future<void> Function()? onTrackComplete;
  Future<void> Function()? onSkipToNext;
  Future<void> Function()? onSkipToPrevious;

  /// Disparado cuando la fuente no se puede reproducir (p. ej. un stream de
  /// radio HTTP bloqueado en web por mixed content, o un formato que el
  /// navegador no soporta -> MEDIA_ELEMENT_ERROR Code 4). La UI lo usa para
  /// avisar al usuario en vez de dejar el reproductor colgado en "loading".
  Future<void> Function(Object error)? onPlaybackError;

  Future<void> playUrl({
    required String url,
    required String id,
    required String title,
    required String artist,
    String? artUrl,
    String? mimeType,
    Duration? canonicalDuration,
    Map<String, String> requestHeaders = const {},
    bool proxyRemoteSource = false,
    int? sourceContentLength,
  }) async {
    final generation = ++_sourceGeneration;
    if (!await _resetForNewSource(generation)) return;
    if (canonicalDuration != null && canonicalDuration > Duration.zero) {
      _duration = canonicalDuration;
      _hasTrustedDuration = true;
    }
    _setMediaItem(id: id, title: title, artist: artist, artUrl: artUrl);
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.loading,
        playing: true,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
      ),
    );
    try {
      await _playRemoteSource(
        url: url,
        mimeType: mimeType,
        requestHeaders: requestHeaders,
        proxyRemoteSource: proxyRemoteSource,
        sourceContentLength: sourceContentLength,
      );
      if (!_isCurrentSource(generation)) return;
      _isSwitchingSource = false;
      _startFadeIn();
    } catch (error, stack) {
      if (!_isCurrentSource(generation)) return;
      _isSwitchingSource = false;
      await _handlePlaybackError(error, stack, generation);
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<void> playFile({
    required String filePath,
    required String id,
    required String title,
    required String artist,
    String? artUrl,
    Duration? canonicalDuration,
  }) async {
    final generation = ++_sourceGeneration;
    if (!await _resetForNewSource(generation)) return;
    if (canonicalDuration != null && canonicalDuration > Duration.zero) {
      _duration = canonicalDuration;
      _hasTrustedDuration = true;
    }
    _setMediaItem(id: id, title: title, artist: artist, artUrl: artUrl);
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.loading,
        playing: true,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
      ),
    );
    try {
      await player.play(DeviceFileSource(filePath));
      if (!_isCurrentSource(generation)) return;
      _isSwitchingSource = false;
      _startFadeIn();
    } catch (error, stack) {
      if (!_isCurrentSource(generation)) return;
      _isSwitchingSource = false;
      await _handlePlaybackError(error, stack, generation);
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<bool> _resetForNewSource(int generation) async {
    _isSwitchingSource = true;
    _completionFired = true;
    _fadeGeneration++;
    // audioplayers can otherwise keep the previous MediaPlayer/AVPlayer alive
    // briefly, leaving two streams overlapping (most noticeable when the new
    // source is a live radio stream that takes longer to start).
    try {
      await player.stop().timeout(_nativeCleanupTimeout);
    } catch (_) {}
    if (!_isCurrentSource(generation)) return false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _hasTrustedDuration = false;
    _completionFired = false;
    _fadeGeneration++;
    _fadeOutStarted = false;
    await player.setVolume(_smoothTransitions ? 0 : 1);
    return _isCurrentSource(generation);
  }

  bool _isCurrentSource(int generation) => generation == _sourceGeneration;

  Future<void> _playRemoteSource({
    required String url,
    String? mimeType,
    required Map<String, String> requestHeaders,
    required bool proxyRemoteSource,
    required int? sourceContentLength,
  }) async {
    final playableUrl = proxyRemoteSource
        ? await prepareRemoteAudioUrl(
            url: url,
            requestHeaders: requestHeaders,
            mimeType: mimeType,
            contentLength: sourceContentLength,
          )
        : url;
    // El proxy ya entrega Content-Type y una extension real. Forzar el MIME
    // mediante AVURLAssetOverrideMIMETypeKey hace que algunas versiones de
    // AVPlayer marquen una fuente HTTP local valida como `.failed`.
    await player.play(
      UrlSource(playableUrl, mimeType: proxyRemoteSource ? null : mimeType),
    );
  }

  void _startFadeIn() {
    if (!_smoothTransitions) return;
    unawaited(_runFade(from: 0, to: 1, total: _fadeInDuration));
  }

  Future<void> _handleCompletion() => withBackgroundTime(_completeAndAdvance);

  Future<void> _completeAndAdvance() async {
    final generation = _sourceGeneration;
    // Detenemos audioplayers explicitamente para que no siga reproduciendo
    // padding/silencio detras del fin canonico cuando autoplay esta
    // desactivado o no hay siguiente cancion en la cola.
    await player.stop();
    if (!_isCurrentSource(generation)) return;
    _position = Duration.zero;
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.completed,
        playing: false,
        updatePosition: _position,
      ),
    );
    // Se espera al hook para que la tarea en segundo plano dure hasta que la
    // siguiente cancion haya empezado a sonar.
    final hook = onTrackComplete;
    if (hook != null) {
      try {
        await hook();
      } catch (error, stack) {
        debugPrint('Track complete hook failed: $error\n$stack');
      }
    }
  }

  Future<void> _handlePlaybackError(
    Object error,
    StackTrace stack,
    int generation,
  ) async {
    if (!_isCurrentSource(generation)) return;
    debugPrint('Audio playback error: $error');
    // Evita que onPositionChanged dispare un "completion" fantasma sobre una
    // fuente que nunca llego a sonar.
    _completionFired = true;
    _fadeGeneration++;
    try {
      await player.stop();
    } catch (_) {}
    if (!_isCurrentSource(generation)) return;
    // Restauramos volumen para que la proxima fuente no quede en silencio por
    // el fade-in que no llego a completarse.
    try {
      await player.setVolume(1);
    } catch (_) {}
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
        errorMessage: error.toString(),
      ),
    );
    final hook = onPlaybackError;
    if (hook != null) {
      unawaited(hook(error));
    }
  }

  void _ignorePlayerStreamError(Object _, StackTrace _) {
    // The awaited play/setSource call owns source errors. Without an error
    // handler, every derived audioplayers stream reports the same platform
    // failure as a separate uncaught exception.
  }

  void _applyDuration(Duration duration, {bool trusted = false}) {
    _duration = duration;
    if (trusted) _hasTrustedDuration = true;
    final current = mediaItem.value;
    if (current != null) {
      mediaItem.add(current.copyWith(duration: duration));
    }
    _broadcastPlaybackState();
  }

  @override
  Future<void> play() => player.resume();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() async {
    final generation = ++_sourceGeneration;
    _isSwitchingSource = true;
    _completionFired = true;
    _fadeGeneration++;
    try {
      await player.stop();
    } catch (error) {
      debugPrint('Could not stop previous audio source: $error');
    }
    if (!_isCurrentSource(generation)) return;
    _position = Duration.zero;
    _duration = Duration.zero;
    _hasTrustedDuration = false;
    _playerState = PlayerState.stopped;
    _isSwitchingSource = false;
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
      ),
    );
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await player.seek(position);
    _position = position;
    _broadcastPlaybackState();
  }

  @override
  Future<void> fastForward() {
    return seek(
      _boundedPosition(_position + AudioService.config.fastForwardInterval),
    );
  }

  @override
  Future<void> rewind() {
    return seek(
      _boundedPosition(_position - AudioService.config.rewindInterval),
    );
  }

  @override
  Future<void> skipToNext() async {
    final hook = onSkipToNext;
    if (hook == null) return;
    await withBackgroundTime(hook);
  }

  @override
  Future<void> skipToPrevious() async {
    final hook = onSkipToPrevious;
    if (hook != null) {
      await withBackgroundTime(hook);
      return;
    }
    await seek(Duration.zero);
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await player.dispose();
  }

  void _setMediaItem({
    required String id,
    required String title,
    required String artist,
    String? artUrl,
  }) {
    mediaItem.add(
      MediaItem(
        id: id,
        title: title.isEmpty ? 'StreamBeat' : title,
        artist: artist.isEmpty ? 'StreamBeat' : artist,
        artUri: artUrl == null || artUrl.isEmpty ? null : Uri.parse(artUrl),
        duration: _duration == Duration.zero ? null : _duration,
      ),
    );
  }

  Duration _boundedPosition(Duration position) {
    if (position < Duration.zero) return Duration.zero;
    if (_duration > Duration.zero && position > _duration) return _duration;
    return position;
  }

  void _broadcastPlaybackState() {
    final playing = _playerState == PlayerState.playing;
    final processingState = switch (_playerState) {
      PlayerState.stopped => AudioProcessingState.idle,
      PlayerState.completed => AudioProcessingState.completed,
      _ => AudioProcessingState.ready,
    };

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {MediaAction.seek},
        processingState: processingState,
        playing: playing,
        updatePosition: _position,
        // audioplayers no expone la cantidad de bytes/tiempo almacenados. La
        // posicion de reproduccion no es un buffer y publicarla como tal hacia
        // que algunas interfaces parecieran seguir cargando la pista anterior.
        bufferedPosition: Duration.zero,
        speed: 1,
      ),
    );

    debugPrint('Background audio state: $_playerState');
  }
}
