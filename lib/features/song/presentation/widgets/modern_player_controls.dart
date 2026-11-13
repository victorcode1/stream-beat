import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flutter/material.dart';

import 'track_change_transition.dart';

class ModernPlayerControls extends StatelessWidget {
  final ThemeData theme;
  final bool isDark;
  final Duration effectiveDuration;
  final Duration position;
  final bool isPlaying;
  final bool isMuted;
  final double volume;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onSkipBackward;
  final VoidCallback onSkipForward;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool repeatEnabled;
  final VoidCallback? onToggleRepeat;
  final VoidCallback? onShuffle;
  final String? title;
  final String? author;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  /// Identifica la cancion, para animar el relevo de titulo y artista.
  final String trackKey;

  /// Sentido del cambio: adelante en la cola o de vuelta a la anterior.
  final bool forward;

  /// Variante de escritorio: titulo centrado con barras de ecualizador,
  /// selector Audio/Video y fila de controles secundarios, como en el mockup
  /// "Escritorio · Reproduciendo". En movil nada de esto cabe.
  final bool wide;

  /// Reproduciendo el video en vez de solo el audio.
  final bool isVideo;

  /// Alterna entre audio y video. En escritorio este era el unico control que
  /// no tenia donde vivir: los chips del pie solo se dibujan en movil.
  final VoidCallback? onToggleVideo;

  /// Abre o pliega el riel de cola.
  final VoidCallback? onToggleQueue;

  /// Velocidad de reproduccion actual (1.0 = normal).
  final double playbackRate;

  /// Cicla la velocidad de reproduccion.
  final VoidCallback? onCyclePlaybackRate;

  const ModernPlayerControls({
    super.key,
    required this.theme,
    required this.isDark,
    required this.effectiveDuration,
    required this.position,
    required this.isPlaying,
    required this.isMuted,
    required this.volume,
    required this.onTogglePlayPause,
    required this.onSeek,
    required this.onSkipBackward,
    required this.onSkipForward,
    required this.onToggleMute,
    required this.onVolumeChanged,
    this.onPrevious,
    this.onNext,
    this.repeatEnabled = false,
    this.onToggleRepeat,
    this.onShuffle,
    this.title,
    this.author,
    this.isFavorite = false,
    this.onToggleFavorite,
    this.trackKey = '',
    this.forward = true,
    this.wide = false,
    this.isVideo = false,
    this.onToggleVideo,
    this.onToggleQueue,
    this.playbackRate = 1,
    this.onCyclePlaybackRate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      // Sin panel: el control fluye con el fondo inmersivo (igual al mockup),
      // sin tarjeta redondeada ni sombra que lo separe del artwork.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Titulo de la cancion + artista + favorito (diseno StreamBeat,
          // pantalla D): el protagonista del reproductor inmersivo, sobre la
          // onda de progreso.
          if ((title ?? '').isNotEmpty) ...[
            if (wide)
              // Escritorio: titulo centrado con las barras de ecualizador al
              // lado, como en el mockup. El favorito baja a la fila de
              // controles secundarios.
              TrackChangeTransition(
                trackKey: trackKey.isNotEmpty ? trackKey : (title ?? ''),
                forward: forward,
                slide: 0.10,
                scaleFrom: 0.98,
                duration: const Duration(milliseconds: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _EqualizerBars(
                          playing: isPlaying,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineLarge?.copyWith(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.34,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if ((author ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        author!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TrackChangeTransition(
                      trackKey: trackKey.isNotEmpty ? trackKey : (title ?? ''),
                      forward: forward,
                      alignment: Alignment.centerLeft,
                      slide: 0.10,
                      scaleFrom: 0.98,
                      duration: const Duration(milliseconds: 360),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          if ((author ?? '').isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              author!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (onToggleFavorite != null)
                    IconButton(
                      tooltip: LocaleKeys.add_to_favorites.tr(),
                      onPressed: onToggleFavorite,
                      iconSize: 28,
                      icon: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFavorite
                            ? const Color(0xFFFF4D6D)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 14),
          ],
          // Selector Audio / Video del mockup, entre el titulo y la onda.
          if (wide && onToggleVideo != null) ...[
            _ModeToggle(
              theme: theme,
              isVideo: isVideo,
              onSelect: onToggleVideo!,
            ),
            const SizedBox(height: 22),
          ],
          Builder(
            builder: (_) {
              final hasDuration = effectiveDuration.inMilliseconds > 0;
              final maxMs = hasDuration
                  ? effectiveDuration.inMilliseconds.toDouble()
                  : 1.0;
              final positionMs = position.inMilliseconds.toDouble().clamp(
                0.0,
                maxMs,
              );
              final displayPosition =
                  hasDuration && position > effectiveDuration
                  ? effectiveDuration
                  : position;

              final progress = hasDuration
                  ? (positionMs / maxMs).clamp(0.0, 1.0)
                  : 0.0;

              return Column(
                children: [
                  _WaveformSeekBar(
                    progress: progress,
                    isPlaying: isPlaying,
                    activeColor: theme.colorScheme.primary,
                    inactiveColor: theme.colorScheme.onSurface.withValues(
                      alpha: 0.22,
                    ),
                    onSeek: hasDuration
                        ? (fraction) => onSeek(
                            Duration(milliseconds: (fraction * maxMs).round()),
                          )
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(displayPosition),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(effectiveDuration),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          // Fila principal de transporte del diseno StreamBeat (pantalla D):
          // aleatorio · anterior · play (blanco) · siguiente · repetir.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: LocaleKeys.shuffle.tr(),
                icon: const Icon(Icons.shuffle_rounded),
                iconSize: 26,
                onPressed: onShuffle,
                color: onShuffle == null
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded),
                iconSize: 36,
                onPressed: onPrevious,
                color: onPrevious == null
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
              // Boton principal del reproductor inmersivo: circulo blanco con
              // icono oscuro, tal como el diseno StreamBeat (pantalla D).
              Container(
                width: wide ? 62 : 72,
                height: wide ? 62 : 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: wide ? 32 : 40,
                  ),
                  onPressed: onTogglePlayPause,
                  color: const Color(0xFF121212),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded),
                iconSize: 36,
                onPressed: onNext,
                color: onNext == null
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
              IconButton(
                tooltip: LocaleKeys.repeat_song.tr(),
                icon: Icon(
                  repeatEnabled
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                ),
                iconSize: 26,
                onPressed: onToggleRepeat,
                color: repeatEnabled
                    ? theme.colorScheme.primary
                    : onToggleRepeat == null
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ],
          ),
          // Fila de controles secundarios del mockup. Aqui viven el favorito y
          // la cola a la izquierda, y velocidad y volumen a la derecha — el
          // volumen ya llegaba a este widget pero no se dibujaba en ningun
          // sitio, asi que en escritorio no habia forma de ajustarlo.
          if (wide) ...[
            const SizedBox(height: 16),
            _SecondaryControls(
              theme: theme,
              isFavorite: isFavorite,
              onToggleFavorite: onToggleFavorite,
              onToggleQueue: onToggleQueue,
              playbackRate: playbackRate,
              onCyclePlaybackRate: onCyclePlaybackRate,
              isMuted: isMuted,
              volume: volume,
              onToggleMute: onToggleMute,
              onVolumeChanged: onVolumeChanged,
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}

/// Barra de progreso tipo onda (waveform) del reproductor inmersivo, igual al
/// diseno StreamBeat. La parte reproducida se pinta con el verde de marca y el
/// resto atenuado; tocar o arrastrar busca esa posicion.
///
/// Mientras suena, las barras ondulan y las cercanas al punto de reproduccion
/// saltan mas, como un medidor en vivo que avanza con la cancion. En pausa se
/// quedan quietas.
class _WaveformSeekBar extends StatefulWidget {
  const _WaveformSeekBar({
    required this.progress,
    required this.isPlaying,
    required this.activeColor,
    required this.inactiveColor,
    required this.onSeek,
  });

  final double progress;
  final bool isPlaying;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<double>? onSeek;

  @override
  State<_WaveformSeekBar> createState() => _WaveformSeekBarState();
}

class _WaveformSeekBarState extends State<_WaveformSeekBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isPlaying) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant _WaveformSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying == oldWidget.isPlaying) return;
    if (widget.isPlaying) {
      _pulse.repeat();
    } else {
      // Se queda donde este, sin saltar de golpe a la forma inicial.
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void seek(double dx) {
          if (widget.onSeek == null || width <= 0) return;
          widget.onSeek!((dx / width).clamp(0.0, 1.0));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => seek(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => seek(d.localPosition.dx),
          // La animacion solo repinta la onda, sin reconstruir los controles.
          child: RepaintBoundary(
            child: SizedBox(
              height: 40,
              width: width,
              child: CustomPaint(
                painter: _WaveformPainter(
                  progress: widget.progress,
                  pulse: _pulse,
                  activeColor: widget.activeColor,
                  inactiveColor: widget.inactiveColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.progress,
    required this.pulse,
    required this.activeColor,
    required this.inactiveColor,
  }) : super(repaint: pulse);

  final double progress;
  final Animation<double> pulse;
  final Color activeColor;
  final Color inactiveColor;

  /// Cuantas barras alrededor del punto de reproduccion saltan con fuerza.
  static const double _focusSpread = 9;

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 3.0;
    const gap = 3.0;
    const step = barWidth + gap;
    final barCount = (size.width / step).floor().clamp(1, 512);
    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;
    final inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.fill;
    final centerY = size.height / 2;
    final maxBar = size.height;
    const minFactor = 0.18;
    final phase = pulse.value * 2 * math.pi;
    final playhead = progress * barCount;

    for (var i = 0; i < barCount; i++) {
      // Patron determinista con varias frecuencias para que parezca una onda
      // real sin depender de aleatoriedad (que rompe el repintado estable).
      final wave =
          0.5 + 0.30 * math.sin(i * 0.55) + 0.20 * math.sin(i * 1.7 + 0.9);
      // Cerca del punto de reproduccion la barra salta mas; lejos apenas
      // respira. Cada barra va desfasada para que no suban todas a la vez.
      final distance = (i - playhead).abs();
      final focus = math.exp(
        -(distance * distance) / (2 * _focusSpread * _focusSpread),
      );
      final amplitude = 0.08 + 0.42 * focus;
      final motion = 1 + amplitude * math.sin(phase * 2 + i * 0.9);
      final factor = (minFactor + (1 - minFactor) * wave * motion).clamp(
        minFactor,
        1.0,
      );
      final barHeight = maxBar * factor;
      final x = i * step;
      final filled = (i + 0.5) / barCount <= progress;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, centerY - barHeight / 2, barWidth, barHeight),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(rect, filled ? activePaint : inactivePaint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pulse != pulse ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}

/// Barras de ecualizador junto al titulo, como en el mockup.
///
/// Solo animan mientras suena: en pausa se quedan quietas a media altura, para
/// que el movimiento signifique algo en vez de ser adorno permanente.
class _EqualizerBars extends StatefulWidget {
  const _EqualizerBars({required this.playing, required this.color});

  final bool playing;
  final Color color;

  @override
  State<_EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<_EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Periodo y desfase de cada barra, para que no latan al unisono.
  static const _bars = <({double period, double delay})>[
    (period: 0.70, delay: 0.00),
    (period: 0.90, delay: 0.15),
    (period: 0.60, delay: 0.30),
    (period: 0.80, delay: 0.10),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.playing) _controller.repeat();
  }

  @override
  void didUpdateWidget(_EqualizerBars old) {
    super.didUpdateWidget(old);
    if (widget.playing == old.playing) return;
    if (widget.playing) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final bar in _bars)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Container(
                    width: 3,
                    height: 16 * _heightFactor(bar.period, bar.delay),
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Onda triangular entre 0.3 y 1.0, como el keyframe `eqbar` del mockup.
  double _heightFactor(double period, double delay) {
    if (!widget.playing) return 0.55;
    final t = ((_controller.value + delay) / period) % 1.0;
    final wave = t < 0.5 ? t * 2 : (1 - t) * 2;
    return 0.3 + wave * 0.7;
  }
}

/// Selector de pastilla Audio / Video.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.theme,
    required this.isVideo,
    required this.onSelect,
  });

  final ThemeData theme;
  final bool isVideo;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeOption(
            theme: theme,
            icon: Icons.music_note_rounded,
            label: LocaleKeys.audio.tr(),
            selected: !isVideo,
            onTap: isVideo ? onSelect : null,
          ),
          _ModeOption(
            theme: theme,
            icon: Icons.videocam_rounded,
            label: LocaleKeys.video.tr(),
            selected: isVideo,
            onTap: isVideo ? null : onSelect,
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.theme,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ThemeData theme;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? const Color(0xFF121212)
        : theme.colorScheme.onSurface.withValues(alpha: 0.75);

    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 7),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila inferior del reproductor de escritorio: favorito y cola a la
/// izquierda; velocidad y volumen a la derecha.
class _SecondaryControls extends StatelessWidget {
  const _SecondaryControls({
    required this.theme,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onToggleQueue,
    required this.playbackRate,
    required this.onCyclePlaybackRate,
    required this.isMuted,
    required this.volume,
    required this.onToggleMute,
    required this.onVolumeChanged,
  });

  final ThemeData theme;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onToggleQueue;
  final double playbackRate;
  final VoidCallback? onCyclePlaybackRate;
  final bool isMuted;
  final double volume;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolumeChanged;

  @override
  Widget build(BuildContext context) {
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onToggleFavorite != null)
              IconButton(
                tooltip: LocaleKeys.add_to_favorites.tr(),
                iconSize: 20,
                color: isFavorite ? const Color(0xFFFF4D6D) : muted,
                icon: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
                onPressed: onToggleFavorite,
              ),
            if (onToggleQueue != null)
              IconButton(
                tooltip: LocaleKeys.queue.tr(),
                iconSize: 20,
                color: muted,
                icon: const Icon(Icons.queue_music_rounded),
                onPressed: onToggleQueue,
              ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onCyclePlaybackRate != null) ...[
              Tooltip(
                message: LocaleKeys.playback_speed.tr(),
                child: OutlinedButton(
                  onPressed: onCyclePlaybackRate,
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 4,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: muted,
                    side: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.16,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    '${playbackRate.toStringAsFixed(playbackRate % 1 == 0 ? 1 : 2)}×',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
            ],
            IconButton(
              tooltip: LocaleKeys.volume.tr(),
              iconSize: 19,
              color: muted,
              icon: Icon(
                isMuted || volume == 0
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
              ),
              onPressed: onToggleMute,
            ),
            SizedBox(
              width: 90,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: theme.colorScheme.onSurface,
                  inactiveTrackColor: theme.colorScheme.onSurface.withValues(
                    alpha: 0.18,
                  ),
                  thumbColor: theme.colorScheme.onSurface,
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5.5,
                  ),
                ),
                child: Slider(
                  value: (isMuted ? 0.0 : volume).clamp(0.0, 1.0),
                  onChanged: onVolumeChanged,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
