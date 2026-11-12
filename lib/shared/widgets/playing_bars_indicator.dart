import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Barras de ecualizador que suben y bajan mientras la cancion suena: es la
/// senal de "esta es la que esta andando" en la cola.
///
/// Cuando la reproduccion se pausa las barras se quedan quietas a media altura,
/// asi el indicador tambien distingue "sonando" de "en pausa".
class PlayingBarsIndicator extends StatefulWidget {
  const PlayingBarsIndicator({
    super.key,
    required this.isPlaying,
    this.color,
    this.size = 18,
    this.barCount = 4,
  });

  final bool isPlaying;
  final Color? color;

  /// Lado del cuadrado que ocupa el indicador.
  final double size;

  final int barCount;

  @override
  State<PlayingBarsIndicator> createState() => _PlayingBarsIndicatorState();
}

class _PlayingBarsIndicatorState extends State<PlayingBarsIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isPlaying) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant PlayingBarsIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying == oldWidget.isPlaying) return;
    if (widget.isPlaying) {
      _controller.repeat();
    } else {
      // Se detiene donde este, sin volver de golpe al inicio.
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
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    // Barras del mismo ancho separadas por un hueco igual de ancho.
    final barWidth = widget.size / (widget.barCount * 2 - 1);

    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var index = 0; index < widget.barCount; index++)
              _bar(index: index, color: color, width: barWidth),
          ],
        ),
      ),
    );
  }

  Widget _bar({
    required int index,
    required Color color,
    required double width,
  }) {
    // Cada barra va desfasada, asi el conjunto se mueve como un ecualizador y
    // no como un solo bloque.
    final phase = (_controller.value + index / widget.barCount) % 1;
    final wave = widget.isPlaying
        ? (math.sin(phase * 2 * math.pi) + 1) / 2
        : 0.4;

    return Container(
      width: width,
      height: widget.size * (0.3 + 0.7 * wave),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(width),
      ),
    );
  }
}
