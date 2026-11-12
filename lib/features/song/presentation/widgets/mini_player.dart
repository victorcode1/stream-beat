import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flow_music/core/audio/background_audio_handler.dart';
import 'package:flow_music/core/routes/routes.dart';
import 'package:flow_music/features/autoplay/presentation/controllers/autoplay_queue_controller.dart';
import 'package:flow_music/features/radio/presentation/controllers/radio_queue_controller.dart';
import 'package:flow_music/features/radio/presentation/pages/radio_player_page.dart';
import 'package:flow_music/features/radio/presentation/utils/play_radio_station.dart';
import 'package:flow_music/features/song/presentation/controllers/song_controller.dart';
import 'package:flow_music/features/song/presentation/widgets/desktop_now_playing_bar.dart';
import 'package:flow_music/features/song/presentation/widgets/track_change_transition.dart';
import 'package:flow_music/shared/widgets/playing_bars_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Barra compacta de reproduccion que aparece anclada al fondo de la
/// pantalla principal cuando hay audio en segundo plano. Permite al
/// usuario ver que esta sonando, pausar/reanudar y abrir el reproductor
/// completo. La barra de progreso usa los streams del propio
/// `AudioPlayer` para mantenerse fluida sin depender de broadcasts del
/// `PlaybackState` (que solo se emiten en cambios de estado).
///
/// Se oculta cuando no hay un `MediaItem` real (titulo vacio o placeholder
/// "StreamBeat") o cuando el estado de procesamiento queda en `idle`
/// (stop explicito).
class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key, this.desktop = false});

  /// Dibuja la barra fija de 72px del escritorio en vez de la tarjeta
  /// flotante movil. Comparten las suscripciones de audio de este widget, solo
  /// cambia la presentacion.
  final bool desktop;

  /// Altura total que el widget reserva (card + margenes). El `AppBar`
  /// wrapper la consume al calcular su `preferredSize`, asi no aparece
  /// "BOTTOM OVERFLOWED" en runtime cuando los componentes piden mas
  /// pixeles de los que el contenedor concedio.
  static const double kHeight = 76;

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer> {
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _isPlaying = false;

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<MediaItem?>? _mediaItemSubscription;
  String? _mediaItemId;

  @override
  void initState() {
    super.initState();
    final player = flowAudioHandler.player;
    _isPlaying = player.state == PlayerState.playing;
    _mediaItemId = flowAudioHandler.mediaItem.value?.id;
    _mediaItemSubscription = flowAudioHandler.mediaItem.listen((item) {
      if (!mounted || item?.id == _mediaItemId) return;
      setState(() {
        _mediaItemId = item?.id;
        _position = Duration.zero;
        _duration = item?.duration;
      });
    });
    _positionSubscription = player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durationSubscription = player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    }, onError: (Object _, StackTrace _) {});
    _playerStateSubscription = player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _mediaItemSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: flowAudioHandler.mediaItem,
      builder: (context, snapshot) {
        final item = snapshot.data;
        if (!_isRealItem(item)) return const SizedBox.shrink();
        return StreamBuilder<PlaybackState>(
          stream: flowAudioHandler.playbackState,
          builder: (context, stateSnapshot) {
            final playback = stateSnapshot.data;
            final isIdle =
                playback?.processingState == AudioProcessingState.idle;
            if (isIdle) return const SizedBox.shrink();
            final isBuffering =
                playback?.processingState == AudioProcessingState.loading ||
                playback?.processingState == AudioProcessingState.buffering;
            final autoplayQueue = ref.watch(autoplayQueueControllerProvider);
            final autoplayNotifier = ref.read(
              autoplayQueueControllerProvider.notifier,
            );
            // Cuando suena una emisora, el song controller queda sin videoId,
            // asi que next/prev deben recorrer la cola de radio en vez de la de
            // canciones.
            final isRadio = ref.watch(songController).currentVideoId == null;
            final radioQueue = ref.watch(radioQueueControllerProvider);
            final onPrevious = isRadio
                ? (radioQueue.hasPrevious
                      ? () =>
                            playPreviousRadioStation(context: context, ref: ref)
                      : null)
                : (autoplayQueue.hasPrevious
                      ? () => _playFromQueue(autoplayNotifier.playPrevious())
                      : null);
            final onNext = isRadio
                ? (radioQueue.hasNext
                      ? () => playNextRadioStation(context: context, ref: ref)
                      : null)
                : (autoplayQueue.hasNext
                      ? () async =>
                            _playFromQueue(await autoplayNotifier.playNext())
                      : null);

            if (widget.desktop) {
              return DesktopNowPlayingBar(
                item: item!,
                isPlaying: _isPlaying,
                isBuffering: isBuffering,
                progress: _progressFraction(item),
                position: _position,
                duration: item.duration ?? _duration,
                onToggle: _togglePlayPause,
                onPrevious: onPrevious,
                onNext: onNext,
                onStop: () => flowAudioHandler.stop(),
                onOpen: _openPlayer,
              );
            }

            return _MiniPlayerBar(
              item: item!,
              isPlaying: _isPlaying,
              isBuffering: isBuffering,
              progress: _progressFraction(item),
              onToggle: _togglePlayPause,
              onPrevious: onPrevious,
              onNext: onNext,
              onStop: () => flowAudioHandler.stop(),
              onOpen: _openPlayer,
            );
          },
        );
      },
    );
  }

  bool _isRealItem(MediaItem? item) {
    if (item == null) return false;
    final title = item.title.trim();
    return title.isNotEmpty && title != 'StreamBeat';
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      flowAudioHandler.pause();
    } else {
      flowAudioHandler.play();
    }
  }

  Future<void> _playFromQueue(NextTrack? track) async {
    if (track == null) return;
    final controller = ref.read(songController);
    final resolved = track.resolved;
    if (resolved != null) {
      await controller.playPrefetched(resolved);
    } else {
      await controller.playAudio(id: track.suggestion.videoId);
    }
  }

  void _openPlayer() {
    final id = flowAudioHandler.mediaItem.value?.id;
    if (id == null || id.isEmpty) return;
    // When a radio station is playing, the song controller has been cleared
    // and the audio handler's id is the station UUID — opening the song page
    // would render stale state from the previous YouTube track, so we route to
    // the dedicated radio player instead.
    final hasSong = ref.read(songController).currentVideoId != null;
    if (!hasSong) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const RadioPlayerPage()));
      return;
    }
    ref
        .read(routeProvider)
        .pushNamed('playSong', queryParameters: {'idSong': id});
  }

  double? _progressFraction(MediaItem item) {
    final duration = item.duration ?? _duration;
    if (duration == null || duration.inMilliseconds <= 0) return null;
    final position = _position > duration ? duration : _position;
    final ratio = position.inMilliseconds / duration.inMilliseconds;
    return ratio.clamp(0.0, 1.0);
  }
}

class _MiniPlayerBar extends StatelessWidget {
  const _MiniPlayerBar({
    required this.item,
    required this.isPlaying,
    required this.isBuffering,
    required this.progress,
    required this.onToggle,
    required this.onPrevious,
    required this.onNext,
    required this.onStop,
    required this.onOpen,
  });

  final MediaItem item;
  final bool isPlaying;
  final bool isBuffering;
  final double? progress;
  final VoidCallback onToggle;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onStop;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Card flotante del diseno StreamBeat (pantalla E): el mini player se
    // separa del borde con margen, esquinas redondeadas y sombra, flotando
    // sobre la barra de navegacion (que es quien gestiona el area segura).
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Material(
        color: colors.surfaceContainerHigh,
        elevation: 10,
        shadowColor: colors.scrim.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 60,
          child: InkWell(
            onTap: onOpen,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (progress == null)
                  Container(height: 2, color: colors.surfaceContainerHighest)
                else
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 2,
                    backgroundColor: colors.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(colors.primary),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        // El relevo de cancion se desliza en vez de saltar,
                        // igual que en el reproductor completo.
                        TrackChangeTransition(
                          trackKey: item.id,
                          slide: 0.35,
                          duration: const Duration(milliseconds: 320),
                          child: _Artwork(
                            artUri: item.artUri,
                            color: colors.primary,
                            isPlaying: isPlaying,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TrackChangeTransition(
                            trackKey: item.id,
                            alignment: Alignment.centerLeft,
                            slide: 0.12,
                            scaleFrom: 0.98,
                            duration: const Duration(milliseconds: 320),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (item.artist != null &&
                                    item.artist!.isNotEmpty)
                                  Text(
                                    item.artist!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        _MiniTransportButton(
                          tooltip: 'Previous',
                          icon: Icons.skip_previous_rounded,
                          onPressed: onPrevious,
                        ),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.primary,
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            tooltip: isPlaying ? 'Pause' : 'Play',
                            icon: isBuffering
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                            onPressed: isBuffering ? null : onToggle,
                          ),
                        ),
                        _MiniTransportButton(
                          tooltip: 'Next',
                          icon: Icons.skip_next_rounded,
                          onPressed: onNext,
                        ),
                        SizedBox(
                          width: 36,
                          height: 40,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            tooltip: 'Stop',
                            icon: Icon(
                              Icons.close_rounded,
                              size: 22,
                              color: colors.onSurfaceVariant,
                            ),
                            onPressed: onStop,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

@Preview(name: 'Mini player bar')
Widget previewMiniPlayerBar() {
  return MaterialApp(
    home: Scaffold(
      bottomNavigationBar: _MiniPlayerBar(
        item: const MediaItem(
          id: 'preview-song',
          title: 'Brillo de medianoche',
          artist: 'StreamBeat Session',
          duration: Duration(minutes: 3, seconds: 24),
        ),
        isPlaying: true,
        isBuffering: false,
        progress: 0.42,
        onToggle: () {},
        onPrevious: () {},
        onNext: () {},
        onStop: () {},
        onOpen: () {},
      ),
    ),
  );
}

class _MiniTransportButton extends StatelessWidget {
  const _MiniTransportButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 32,
      height: 40,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        icon: Icon(
          icon,
          size: 24,
          color: onPressed == null
              ? colors.onSurfaceVariant.withValues(alpha: 0.35)
              : colors.onSurfaceVariant,
        ),
        onPressed: onPressed,
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({
    required this.artUri,
    required this.color,
    required this.isPlaying,
  });

  final Uri? artUri;
  final Color color;

  /// Superpone las barras animadas mientras suena el audio.
  final bool isPlaying;

  static const _size = 38.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _image(),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AnimatedOpacity(
              opacity: isPlaying ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.42),
                child: Center(
                  child: PlayingBarsIndicator(
                    isPlaying: isPlaying,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _image() {
    const size = _size;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.music_note_rounded, size: 22, color: color),
    );
    if (artUri == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        artUri.toString(),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}
