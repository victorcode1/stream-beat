import 'package:flow_music/core/theme/custom_theme.dart';
import 'package:flow_music/core/theme/visual_style.dart';
import 'package:flutter/material.dart';

/// Fondo ambiente de la app. Usa el color primario del tema, por lo que cambia
/// automaticamente al elegir otro acento en Configuracion.
class FlowAmbientBackground extends StatelessWidget {
  const FlowAmbientBackground({
    super.key,
    required this.child,
    this.intensity = 1,
  });

  final Widget child;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final extras = theme.extension<FlowThemeExtras>();
    final accent = colors.primary;
    final isDark = theme.brightness == Brightness.dark;
    final clampedIntensity = intensity.clamp(0.0, 1.4);

    double alpha(double dark, double light) {
      return (isDark ? dark : light) * clampedIntensity;
    }

    // Solo el estilo Clasico lleva los resplandores del acento; los demas
    // estilos pintan su propio fondo (tela, negro o escala neutra).
    if (context.styleTokens.style != VisualStyle.clasico) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          gradient: extras?.secondaryGradient,
        ),
        child: child,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        gradient: extras?.secondaryGradient,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -1.18),
                radius: 1.05,
                colors: [
                  accent.withValues(alpha: alpha(0.34, 0.13)),
                  accent.withValues(alpha: alpha(0.12, 0.05)),
                  Colors.transparent,
                ],
                stops: const [0, 0.42, 1],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.82, 0.15),
                radius: 0.95,
                colors: [
                  accent.withValues(alpha: alpha(0.13, 0.05)),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: isDark ? 0.16 : 0.03),
                ],
                stops: const [0.55, 1],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
