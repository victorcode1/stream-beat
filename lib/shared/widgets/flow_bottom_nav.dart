import 'package:flow_music/core/theme/visual_style.dart';
import 'package:flutter/material.dart';

/// Destino de la barra de navegacion inferior de StreamBeat.
class FlowNavDestination {
  const FlowNavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
}

/// Barra de navegacion inferior del diseno StreamBeat: iconos + etiqueta, con
/// el destino activo en verde de marca. Es un widget "tonto": cada destino
/// decide si esta seleccionado y que hacer al tocarse, asi el shell mantiene la
/// logica de rutas en un solo lugar.
class FlowBottomNav extends StatelessWidget {
  const FlowBottomNav({super.key, required this.destinations});

  final List<FlowNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final inverted = _isInverted(context);

    return Material(
      color: inverted ? Colors.black : colors.surface,
      child: SafeArea(
        top: false,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: inverted
                    ? Colors.white.withValues(alpha: 0.1)
                    : colors.outlineVariant.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              for (final destination in destinations)
                Expanded(child: _FlowNavItem(destination: destination)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlowNavItem extends StatelessWidget {
  const _FlowNavItem({required this.destination});

  final FlowNavDestination destination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = destination.selected;
    final color = _isInverted(context)
        ? Colors.white.withValues(alpha: selected ? 1 : 0.6)
        : selected
        ? colors.primary
        : colors.onSurfaceVariant;

    return InkWell(
      onTap: destination.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selected ? destination.activeIcon : destination.icon,
            size: 22,
            color: color,
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10.5,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Monocromo lleva la barra siempre negra con iconos blancos, en modo claro
/// y oscuro; el destino activo se distingue por el blanco pleno.
bool _isInverted(BuildContext context) {
  return context.styleTokens.style == VisualStyle.monocromo;
}
