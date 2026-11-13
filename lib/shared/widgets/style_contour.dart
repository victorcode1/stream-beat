import 'package:flow_music/core/theme/visual_style.dart';
import 'package:flutter/material.dart';

/// Gesto distintivo del estilo Mola: lo que suena queda rodeado de contornos
/// de color concentricos, como los canales recortados de una mola. En los
/// estilos sin contornos devuelve el hijo tal cual.
class StyleContour extends StatelessWidget {
  const StyleContour({
    super.key,
    required this.child,
    required this.radius,
    this.strokeWidth = 2,
    this.gap = 3,
    this.maxRings = 3,
  });

  final Widget child;

  /// Radio de la forma interior; cada anillo lo agranda en su grosor.
  final double radius;
  final double strokeWidth;
  final double gap;

  /// Cuantos anillos dibujar como maximo, del interior hacia afuera.
  final int maxRings;

  @override
  Widget build(BuildContext context) {
    final colors = context.styleTokens.contourColors;
    if (colors.isEmpty) return child;

    // Del anillo interior al exterior: el primer color queda pegado al hijo.
    var result = child;
    var currentRadius = radius;
    for (final color in colors.take(maxRings)) {
      currentRadius += strokeWidth + gap;
      result = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(currentRadius),
          border: Border.all(color: color, width: strokeWidth),
        ),
        child: Padding(
          padding: EdgeInsets.all(strokeWidth + gap),
          child: result,
        ),
      );
    }
    return result;
  }
}
