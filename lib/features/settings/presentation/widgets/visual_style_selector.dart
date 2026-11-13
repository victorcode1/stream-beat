import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/theme/visual_style.dart';
import 'package:flutter/material.dart';

/// Lista de estilos visuales para elegir en Ajustes. El cambio se aplica al
/// instante en toda la app.
class VisualStyleSelector extends StatelessWidget {
  const VisualStyleSelector({
    super.key,
    required this.current,
    required this.onSelected,
  });

  final VisualStyle current;
  final ValueChanged<VisualStyle> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final style in VisualStyle.values)
          _VisualStyleTile(
            style: style,
            selected: style == current,
            onTap: () => onSelected(style),
          ),
      ],
    );
  }
}

class _VisualStyleTile extends StatelessWidget {
  const _VisualStyleTile({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final VisualStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              _StyleSwatch(colors: style.swatches),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      style.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      style.descriptionKey.tr(),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Las tres telas del estilo, superpuestas en franjas.
class _StyleSwatch extends StatelessWidget {
  const _StyleSwatch({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          // Sin estirar, cada franja vacia mediria 0 de ancho.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final color in colors)
              Expanded(child: ColoredBox(color: color)),
          ],
        ),
      ),
    );
  }
}
