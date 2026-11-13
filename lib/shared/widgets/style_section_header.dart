import 'package:flow_music/core/theme/visual_style.dart';
import 'package:flutter/material.dart';

/// Encabezado de seccion de la app. Cada estilo le pone su voz: Mola lo tiñe
/// con una tela y tres franjas, Carteles lo imprime en una banda de color y en
/// mayusculas, Clasico y Monocromo lo dejan en el color del texto.
class StyleSectionHeader extends StatelessWidget {
  const StyleSectionHeader({
    super.key,
    required this.title,
    required this.index,
    this.trailing,
  });

  final String title;

  /// Posicion de la seccion en la pantalla; elige el color de su tela.
  final int index;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.styleTokens;
    final sectionColor = tokens.sectionColor(index);
    final text = tokens.uppercaseHeadings ? title.toUpperCase() : title;
    final baseStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: tokens.style == VisualStyle.carteles
          ? FontWeight.w400
          : FontWeight.w800,
      letterSpacing: tokens.style == VisualStyle.carteles ? 0.4 : -0.3,
    );

    final Widget heading;
    if (tokens.style == VisualStyle.carteles && sectionColor != null) {
      // Carteles: el titulo impreso sobre una banda de papel fluorescente.
      heading = DecoratedBox(
        decoration: BoxDecoration(color: sectionColor),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 12, 2),
          child: Text(
            text,
            style: baseStyle?.copyWith(color: const Color(0xFF0A0A0A)),
          ),
        ),
      );
    } else if (tokens.style == VisualStyle.mola && sectionColor != null) {
      // Mola: tres franjas cortas de tela delante del titulo teñido.
      heading = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MolaStripes(colors: tokens.contourColors, lead: sectionColor),
          const SizedBox(width: 10),
          Flexible(
            child: Text(text, style: baseStyle?.copyWith(color: sectionColor)),
          ),
        ],
      );
    } else {
      heading = Text(text, style: baseStyle);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Align(alignment: Alignment.centerLeft, child: heading),
        ),
        ?trailing,
      ],
    );
  }
}

class _MolaStripes extends StatelessWidget {
  const _MolaStripes({required this.colors, required this.lead});

  final List<Color> colors;
  final Color lead;

  @override
  Widget build(BuildContext context) {
    final stripes = [lead, ...colors.where((color) => color != lead)].take(3);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, color) in stripes.indexed)
          Container(
            width: 18 - index * 4,
            height: 3,
            margin: const EdgeInsets.symmetric(vertical: 1.5),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}
