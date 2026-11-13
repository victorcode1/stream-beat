import 'package:flutter/material.dart';

/// Estilos visuales que se eligen en Ajustes.
///
/// La estructura de las pantallas es la misma en todos; cada estilo cambia
/// color, tipografia, forma y su gesto distintivo. Mola y Carteles son mundos
/// oscuros y siempre se ven en oscuro; Clasico y Monocromo siguen la apariencia
/// elegida y usan el color de acento de Ajustes.
enum VisualStyle {
  mola(
    label: 'Mola',
    swatches: [Color(0xFFE23B2E), Color(0xFFF2892B), Color(0xFF1FB8A6)],
    alwaysDark: true,
    usesAccent: false,
  ),
  clasico(
    label: 'Clásico',
    swatches: [Color(0xFF18E0C2), Color(0xFF141414), Color(0xFFF5F5F5)],
    alwaysDark: false,
    usesAccent: true,
  ),
  monocromo(
    label: 'Monocromo',
    swatches: [Color(0xFF0B0B0C), Color(0xFF8A8A8E), Color(0xFFF2F2F3)],
    alwaysDark: false,
    usesAccent: true,
  ),
  carteles(
    label: 'Carteles',
    swatches: [Color(0xFFF7E733), Color(0xFFFF3EA5), Color(0xFF3DF56E)],
    alwaysDark: true,
    usesAccent: false,
  );

  const VisualStyle({
    required this.label,
    required this.swatches,
    required this.alwaysDark,
    required this.usesAccent,
  });

  final String label;

  /// Clave de traduccion de la descripcion que muestra Ajustes.
  String get descriptionKey => 'visual_style_${name}_desc';

  /// Colores que representan el estilo en el selector de Ajustes.
  final List<Color> swatches;

  /// El estilo es un mundo oscuro y no cambia con la apariencia del sistema.
  final bool alwaysDark;

  /// El color de acento de Ajustes tiñe este estilo.
  final bool usesAccent;
}

/// Rasgos propios de cada estilo que los widgets leen para su gesto
/// distintivo, ademas del `ColorScheme`.
class FlowStyleTokens extends ThemeExtension<FlowStyleTokens> {
  const FlowStyleTokens({
    required this.style,
    required this.cardRadius,
    required this.contourColors,
    required this.sectionColors,
    required this.uppercaseHeadings,
  });

  final VisualStyle style;

  /// Radio de tarjetas y caratulas.
  final double cardRadius;

  /// Contornos concentricos alrededor de lo que suena (Mola). Vacio cuando el
  /// estilo no los usa.
  final List<Color> contourColors;

  /// Un color por seccion, en orden, para los encabezados (Mola y Carteles).
  /// Vacio cuando las secciones usan el color de texto normal.
  final List<Color> sectionColors;

  /// Los encabezados de seccion van en mayusculas (Carteles).
  final bool uppercaseHeadings;

  /// Color del encabezado de la seccion [index], o null si el estilo no tiñe
  /// las secciones.
  Color? sectionColor(int index) => sectionColors.isEmpty
      ? null
      : sectionColors[index % sectionColors.length];

  @override
  FlowStyleTokens copyWith({
    VisualStyle? style,
    double? cardRadius,
    List<Color>? contourColors,
    List<Color>? sectionColors,
    bool? uppercaseHeadings,
  }) {
    return FlowStyleTokens(
      style: style ?? this.style,
      cardRadius: cardRadius ?? this.cardRadius,
      contourColors: contourColors ?? this.contourColors,
      sectionColors: sectionColors ?? this.sectionColors,
      uppercaseHeadings: uppercaseHeadings ?? this.uppercaseHeadings,
    );
  }

  @override
  FlowStyleTokens lerp(ThemeExtension<FlowStyleTokens>? other, double t) {
    if (other is! FlowStyleTokens) return this;
    // Los estilos son discretos: cambia de golpe a mitad de la transicion.
    return t < 0.5 ? this : other;
  }
}

extension FlowStyleTokensContext on BuildContext {
  /// Tokens del estilo activo. Siempre existen: los agrega `CustomTheme`.
  FlowStyleTokens get styleTokens =>
      Theme.of(this).extension<FlowStyleTokens>() ??
      const FlowStyleTokens(
        style: VisualStyle.clasico,
        cardRadius: 16,
        contourColors: [],
        sectionColors: [],
        uppercaseHeadings: false,
      );
}
