import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;

import 'background_time.dart';
import 'flow_player.dart';
import 'remote_audio_proxy_stub.dart'
    if (dart.library.io) 'remote_audio_proxy_io.dart';

export 'flow_player.dart';

late final FlowAudioHandler flowAudioHandler;

Future<FlowAudioHandler> initFlowAudioHandler() async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

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

/// Pista lista para reproducirse o encolarse en el reproductor nativo.
@immutable
class QueuedTrack {
  const QueuedTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.artUrl,
    this.duration,
    this.filePath,
    this.url,
    this.mimeType,
    this.requestHeaders = const {},
    this.proxyRemoteSource = false,
    this.contentLength,
  }) : assert(filePath != null || url != null);

  final String id;
  final String title;
  final String artist;
  final String? artUrl;
  final Duration? duration;

  /// Copia local (descarga, cache o modo sin conexion). Tiene prioridad.
  final String? filePath;
  final String? url;
  final String? mimeType;
  final Map<String, String> requestHeaders;

  /// Sirve la URL a traves del proxy local (necesario en iOS para YouTube).
  final bool proxyRemoteSource;
  final int? contentLength;

  MediaItem toMediaItem() {
    final art = artUrl;
    final knownDuration = duration;
    return MediaItem(
      id: id,
      title: title.isEmpty ? 'StreamBeat' : title,
      artist: artist.isEmpty ? 'StreamBeat' : artist,
      artUri: art == null || art.isEmpty ? null : Uri.parse(art),
      duration: knownDuration != null && knownDuration > Duration.zero
          ? knownDuration
          : null,
    );
  }
}

/// Reproductor de la app sobre `just_audio`, conectado a `audio_service`.
///
/// El autoplay no depende de que Dart despierte al terminar una cancion: en
/// cuanto una pista empieza, se pide la siguiente ([prepareNextTrack]) y se
/// agrega a la playlist nativa (AVQueuePlayer en iOS, ExoPlayer en Android).
/// Al terminar, el sistema pasa solo a la siguiente aunque iOS tenga la app
/// en segundo plano; Dart solo se entera despues ([onAutoAdvanced]) para
/// actualizar la cola, el historial y la interfaz.
class FlowAudioHandler extends BaseAudioHandler with SeekHandler {
  FlowAudioHandler() {
    _subscriptions
      ..add(
        _player.playerStateStream.listen(
          _onPlayerState,
          onError: _onPlayerStreamError,
        ),
      )
      ..add(_player.currentIndexStream.listen(_onCurrentIndex))
      ..add(_player.durationStream.listen(_onDuration))
      ..add(
        _player
            .createPositionStream(
              minPeriod: positionUpdateInterval,
              maxPeriod: positionUpdateInterval,
            )
            .listen(_onPosition),
      )
      ..add(_player.errorStream.listen(_onPlayerError));
  }

  final ja.AudioPlayer _player = ja.AudioPlayer();

  /// Vista del reproductor para la interfaz.
  late final FlowPlayer player = FlowPlayer(_player);

  /// Reproduce silencio mientras Dart cambia de cancion sin cola nativa.
  ///
  /// iOS suspende una app de audio en segundo plano en cuanto deja de sonar.
  /// Si la siguiente cancion no llego a encolarse, el cambio depende de Dart y
  /// este reproductor evita que el audio se detenga entre una y otra.
  late final ja.AudioPlayer _gapPlayer = ja.AudioPlayer(
    handleInterruptions: false,
  );
  static const _gapAsset = 'assets/audio/silence.wav';
  bool _gapLoaded = false;

  final List<StreamSubscription<Object?>> _subscriptions = [];

  /// Id de la pista que suena (la etiqueta de su fuente nativa).
  String? _currentId;

  /// Id de la pista ya agregada a la playlist nativa detras de la actual.
  String? _queuedNextId;

  Duration _duration = Duration.zero;
  bool _hasTrustedDuration = false;

  /// Evita procesar dos veces el fin de la misma pista.
  bool _completionHandled = false;

  /// La pista actual llego a sonar; un error despues de esto se trata como
  /// fin de pista para que el autoplay continue.
  bool _currentStarted = false;
  bool _repeatCurrent = false;
  PlayerState? _lastLoggedState;

  /// Identifica la carga mas reciente. Las cargas pueden terminar fuera de
  /// orden cuando el usuario toca varias canciones rapidamente; solo la mas
  /// nueva puede publicar estado, iniciar un fade o reportar un error.
  int _sourceGeneration = 0;

  /// Invalida las peticiones de "siguiente pista" de una pista anterior.
  int _queueGeneration = 0;

  static const Duration _fadeOutDuration = Duration(milliseconds: 2500);
  static const Duration _fadeInDuration = Duration(milliseconds: 700);
  static const Duration _fadeStep = Duration(milliseconds: 50);
  bool _smoothTransitions = true;
  bool _fadeOutStarted = false;
  int _fadeGeneration = 0;

  /// Hook fired when the current track finishes and nothing was queued
  /// natively. The app wires this to the autoplay queue.
  Future<void> Function()? onTrackComplete;
  Future<void> Function()? onSkipToNext;
  Future<void> Function()? onSkipToPrevious;

  /// Devuelve la pista que debe sonar despues de [currentId], o `null` si no
  /// hay que encolar nada (autoplay apagado, repetir activo, radio, etc.).
  Future<QueuedTrack?> Function(String currentId)? prepareNextTrack;

  /// Avisa que el reproductor nativo paso solo a la pista [id].
  Future<void> Function(String id)? onAutoAdvanced;

  /// Disparado cuando la fuente no se puede reproducir. La UI lo usa para
  /// avisar al usuario en vez de dejar el reproductor colgado en "loading".
  Future<void> Function(Object error)? onPlaybackError;

  void setSmoothTransitions(bool value) {
    _smoothTransitions = value;
    if (!value) {
      _fadeGeneration++;
      _fadeOutStarted = false;
      unawaited(_player.setVolume(1));
    }
  }

  /// Repite la pista actual en el reproductor nativo.
  Future<void> setRepeatCurrent(bool value) async {
    _repeatCurrent = value;
    await _player.setLoopMode(value ? ja.LoopMode.one : ja.LoopMode.off);
    await refreshQueuedNext();
  }

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
  }) {
    return _playTrack(
      QueuedTrack(
        id: id,
        title: title,
        artist: artist,
        artUrl: artUrl,
        duration: canonicalDuration,
        url: url,
        mimeType: mimeType,
        requestHeaders: requestHeaders,
        proxyRemoteSource: proxyRemoteSource,
        contentLength: sourceContentLength,
      ),
    );
  }

  Future<void> playFile({
    required String filePath,
    required String id,
    required String title,
    required String artist,
    String? artUrl,
    Duration? canonicalDuration,
  }) {
    return _playTrack(
      QueuedTrack(
        id: id,
        title: title,
        artist: artist,
        artUrl: artUrl,
        duration: canonicalDuration,
        filePath: filePath,
      ),
    );
  }

  /// Reemplaza la playlist nativa por [track] y empieza a reproducirla.
  Future<void> _playTrack(QueuedTrack track) async {
    final generation = ++_sourceGeneration;
    _queueGeneration++;
    _queuedNextId = null;
    _completionHandled = false;
    _currentStarted = false;
    _fadeGeneration++;
    _fadeOutStarted = false;
    _setCurrent(track.toMediaItem());
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.loading,
        playing: true,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
      ),
    );

    try {
      final source = await _buildSource(track);
      if (!_isCurrentSource(generation)) return;
      await _player.setVolume(_smoothTransitions ? 0 : 1);
      await _player.setAudioSources([source]);
      if (!_isCurrentSource(generation)) return;
      unawaited(_player.play());
      _startFadeIn();
      unawaited(_queueNextTrack(_queueGeneration));
    } on ja.PlayerInterruptedException {
      // Otra carga reemplazo a esta antes de que terminara.
      return;
    } catch (error, stack) {
      if (!_isCurrentSource(generation)) return;
      _completionHandled = true;
      await _handlePlaybackError(error, stack, generation);
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<ja.AudioSource> _buildSource(QueuedTrack track) async {
    final item = track.toMediaItem();
    final filePath = track.filePath;
    if (filePath != null && filePath.isNotEmpty) {
      return ja.AudioSource.file(filePath, tag: item);
    }

    final url = track.url!;
    // El proxy entrega Content-Type, extension real y las cabeceras que
    // YouTube exige; AVPlayer rechaza las URLs firmadas sin extension.
    final playableUrl = track.proxyRemoteSource
        ? await prepareRemoteAudioUrl(
            url: url,
            requestHeaders: track.requestHeaders,
            mimeType: track.mimeType,
            contentLength: track.contentLength,
          )
        : url;
    return ja.AudioSource.uri(Uri.parse(playableUrl), tag: item);
  }

  /// Pide la siguiente pista y la agrega detras de la actual.
  Future<void> _queueNextTrack(int queueGeneration) async {
    final hook = prepareNextTrack;
    final currentId = _currentId;
    if (hook == null || currentId == null || _queuedNextId != null) return;
    if (_repeatCurrent) return;

    final QueuedTrack? next;
    try {
      next = await hook(currentId);
    } catch (error) {
      debugPrint('Could not prepare next track: $error');
      return;
    }
    if (next == null || next.id == currentId) return;
    if (queueGeneration != _queueGeneration || _queuedNextId != null) return;

    _queuedNextId = next.id;
    try {
      final source = await _buildSource(next);
      if (queueGeneration != _queueGeneration) {
        _queuedNextId = null;
        return;
      }
      await _player.addAudioSource(source);
      debugPrint('Queued next track natively: ${next.id}');
    } catch (error) {
      _queuedNextId = null;
      debugPrint('Could not queue next track ${next.id}: $error');
    }
  }

  /// Quita la siguiente pista encolada y vuelve a pedirla. Se usa cuando
  /// cambia la cola de autoplay o sus ajustes.
  Future<void> refreshQueuedNext() async {
    final generation = ++_queueGeneration;
    if (_queuedNextId != null) {
      _queuedNextId = null;
      final index = _player.currentIndex ?? 0;
      final length = _player.sequence.length;
      if (index + 1 < length) {
        try {
          await _player.removeAudioSourceRange(index + 1, length);
        } catch (error) {
          debugPrint('Could not remove queued track: $error');
        }
      }
    }
    if (generation != _queueGeneration) return;
    await _queueNextTrack(generation);
  }

  /// Id de la pista encolada en el reproductor nativo, si hay una.
  String? get queuedNextId => _queuedNextId;

  void _setCurrent(MediaItem item) {
    _currentId = item.id;
    final duration = item.duration;
    _hasTrustedDuration = duration != null && duration > Duration.zero;
    _duration = _hasTrustedDuration ? duration! : Duration.zero;
    mediaItem.add(item);
  }

  void _onCurrentIndex(int? index) {
    if (index == null) return;
    final sequence = _player.sequence;
    if (index < 0 || index >= sequence.length) return;
    final item = sequence[index].tag;
    if (item is! MediaItem || item.id == _currentId) return;

    // El reproductor nativo paso solo a la siguiente pista.
    debugPrint('Native auto-advance to ${item.id}');
    _queueGeneration++;
    _queuedNextId = null;
    _completionHandled = false;
    _currentStarted = true;
    _fadeGeneration++;
    _fadeOutStarted = false;
    unawaited(_player.setVolume(1));
    _setCurrent(item);
    _broadcastPlaybackState();
    unawaited(_afterAutoAdvance(item.id, index));
  }

  Future<void> _afterAutoAdvance(String id, int index) async {
    // Quita las pistas terminadas para que la playlist no crezca.
    if (index > 0) {
      try {
        await _player.removeAudioSourceRange(0, index);
      } catch (error) {
        debugPrint('Could not trim finished tracks: $error');
      }
    }
    final hook = onAutoAdvanced;
    if (hook != null) {
      try {
        await hook(id);
      } catch (error, stack) {
        debugPrint('Auto-advance hook failed: $error\n$stack');
      }
    }
    // Durante el hook la cola de autoplay avanza y puede pedir la siguiente
    // antes de que la app adopte la pista nueva; esa peticion no encola nada.
    // Ya adoptada, se pide de nuevo si sigue faltando.
    if (_currentId != id || _queuedNextId != null) return;
    await refreshQueuedNext();
  }

  void _onPlayerState(ja.PlayerState state) {
    if (state.processingState == ja.ProcessingState.ready) {
      _currentStarted = true;
    }
    _broadcastPlaybackState();
    if (state.processingState == ja.ProcessingState.completed &&
        !_completionHandled) {
      _completionHandled = true;
      unawaited(_handleCompletion());
    }
  }

  void _onDuration(Duration? duration) {
    if (duration == null || duration <= Duration.zero) return;
    // La duracion de los metadatos es la canonica; la nativa solo se usa si
    // no hay otra.
    if (_hasTrustedDuration) return;
    _duration = duration;
    final current = mediaItem.value;
    if (current != null && current.id == _currentId) {
      mediaItem.add(current.copyWith(duration: duration));
    }
    _broadcastPlaybackState();
  }

  void _onPosition(Duration position) {
    // Con la siguiente pista encolada el paso es continuo; el fundido solo se
    // usa cuando el cambio depende de Dart.
    if (_queuedNextId != null || _repeatCurrent) return;
    _maybeStartFadeOut(position);
  }

  void _onPlayerError(ja.PlayerException error) {
    debugPrint('Audio player error: ${error.code} ${error.message}');
    // Un fallo a mitad de una pista que ya sonaba (p. ej. se corto la red) no
    // debe detener el autoplay.
    if (!_currentStarted || _completionHandled) return;
    _completionHandled = true;
    unawaited(_handleCompletion());
  }

  void _onPlayerStreamError(Object error, StackTrace stack) {
    // La carga (setAudioSources) ya reporta sus errores; evita duplicarlos
    // como excepciones no atendidas.
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
    await _player.setVolume(from);
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(_fadeStep);
      if (generation != _fadeGeneration) return;
      final volume = (from + (to - from) * (i / steps)).clamp(0.0, 1.0);
      await _player.setVolume(volume);
    }
  }

  void _startFadeIn() {
    if (!_smoothTransitions) return;
    unawaited(_runFade(from: 0, to: 1, total: _fadeInDuration));
  }

  bool _isCurrentSource(int generation) => generation == _sourceGeneration;

  Future<void> _handleCompletion() => _withoutAudioGap(_completeAndAdvance);

  bool get _needsGapAudio =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Ejecuta un cambio de cancion sin dejar a iOS un hueco sin audio.
  Future<void> _withoutAudioGap(Future<void> Function() body) async {
    if (!_needsGapAudio) return withBackgroundTime(body);
    await _startGapAudio();
    try {
      await withBackgroundTime(body);
    } finally {
      await _stopGapAudio();
    }
  }

  Future<void> _startGapAudio() async {
    try {
      if (!_gapLoaded) {
        await _gapPlayer.setLoopMode(ja.LoopMode.one);
        await _gapPlayer.setAudioSource(ja.AudioSource.asset(_gapAsset));
        _gapLoaded = true;
      }
      unawaited(_gapPlayer.play());
    } catch (error) {
      debugPrint('Transition gap audio failed to start: $error');
    }
  }

  Future<void> _stopGapAudio() async {
    try {
      await _gapPlayer.pause();
    } catch (error) {
      debugPrint('Transition gap audio failed to stop: $error');
    }
  }

  Future<void> _completeAndAdvance() async {
    final generation = _sourceGeneration;
    // Queda en pausa al final: si el autoplay no sigue, la interfaz muestra la
    // pista terminada; si sigue, la nueva carga la reemplaza.
    await _player.pause();
    if (!_isCurrentSource(generation)) return;
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.completed,
        playing: false,
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
    _fadeGeneration++;
    try {
      await _player.stop();
    } catch (_) {}
    if (!_isCurrentSource(generation)) return;
    // Restauramos volumen para que la proxima fuente no quede en silencio por
    // el fade-in que no llego a completarse.
    try {
      await _player.setVolume(1);
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

  @override
  Future<void> play() async {
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    final generation = ++_sourceGeneration;
    _queueGeneration++;
    _queuedNextId = null;
    _completionHandled = true;
    _currentStarted = false;
    _fadeGeneration++;
    try {
      await _player.stop();
    } catch (error) {
      debugPrint('Could not stop previous audio source: $error');
    }
    if (!_isCurrentSource(generation)) return;
    _duration = Duration.zero;
    _hasTrustedDuration = false;
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
    await _player.seek(position);
    _broadcastPlaybackState();
  }

  @override
  Future<void> fastForward() {
    return seek(
      _boundedPosition(
        _player.position + AudioService.config.fastForwardInterval,
      ),
    );
  }

  @override
  Future<void> rewind() {
    return seek(
      _boundedPosition(_player.position - AudioService.config.rewindInterval),
    );
  }

  @override
  Future<void> skipToNext() async {
    // Si la siguiente ya esta en la playlist nativa, el salto es inmediato y
    // la app se entera por [onAutoAdvanced], igual que al terminar la pista.
    if (_queuedNextId != null && _player.hasNext) {
      await _player.seekToNext();
      return;
    }
    final hook = onSkipToNext;
    if (hook == null) return;
    await _withoutAudioGap(hook);
  }

  @override
  Future<void> skipToPrevious() async {
    final hook = onSkipToPrevious;
    if (hook != null) {
      await _withoutAudioGap(hook);
      return;
    }
    await seek(Duration.zero);
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    await _gapPlayer.dispose();
  }

  Duration _boundedPosition(Duration position) {
    if (position < Duration.zero) return Duration.zero;
    if (_duration > Duration.zero && position > _duration) return _duration;
    return position;
  }

  void _broadcastPlaybackState() {
    final playing = _player.playing;
    final processingState = switch (_player.processingState) {
      ja.ProcessingState.idle => AudioProcessingState.idle,
      ja.ProcessingState.loading => AudioProcessingState.loading,
      ja.ProcessingState.buffering => AudioProcessingState.buffering,
      ja.ProcessingState.ready => AudioProcessingState.ready,
      ja.ProcessingState.completed => AudioProcessingState.completed,
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
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ),
    );

    final state = player.state;
    if (state != _lastLoggedState) {
      _lastLoggedState = state;
      debugPrint('Background audio state: $state');
    }
  }
}
