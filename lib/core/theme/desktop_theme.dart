import 'package:flow_music/core/theme/custom_theme.dart';
import 'package:flutter/material.dart';

/// Superficies y medidas exclusivas del shell de escritorio (mockup
/// "StreamBeat — Rediseño").
///
/// El tema global de la app ([CustomTheme]) usa grises neutros que funcionan
/// bien en movil. El diseno de escritorio pide un negro azulado frio y rieles
/// mas oscuros que el lienzo, asi que aqui se re-tinta el `ColorScheme` sin
/// tocar el tema compartido: `HomePage` envuelve solo su rama desktop en un
/// `Theme` con [FlowDesktopTheme.of], y movil sigue con los colores de siempre.
///
/// Tokens del diseno (modo oscuro / modo claro):
///
/// | token        | oscuro                  | claro     |
/// |--------------|-------------------------|-----------|
/// | bg           | `#0c0d12`               | `#f4f5f7` |
/// | riel/topbar  | `#0a0b0f`               | `#ffffff` |
/// | divisor      | `rgba(255,255,255,.06)` | `#e9eaee` |
/// | panel        | `rgba(255,255,255,.045)`| `#ffffff` |
/// | borde panel  | `rgba(255,255,255,.08)` | `#e8e9ed` |
/// | busqueda/icono | `rgba(255,255,255,.07)` | `#f1f2f5` |
/// | texto        | `#ffffff`               | `#101014` |
/// | secundario   | `rgba(255,255,255,.58)` | `#6b6c75` |
abstract final class FlowDesktopTheme {
  /// Alto de la barra superior.
  static const double topBarHeight = 60;

  /// Ancho de la barra lateral de navegacion.
  static const double sidebarWidth = 232;

  /// Ancho del riel derecho ("A continuación" / "Letra") del reproductor.
  static const double sideRailWidth = 316;

  /// Alto de la barra de reproduccion inferior.
  static const double nowPlayingBarHeight = 72;

  /// Radio de las pastillas (busqueda, chips de filtro, botones de accion).
  static const double pillRadius = 999;

  /// Devuelve [base] re-tintado con las superficies del diseno de escritorio.
  static ThemeData of(ThemeData base) {
    final isDark = base.brightness == Brightness.dark;
    final colors = isDark
        ? _darkScheme(base.colorScheme)
        : _lightScheme(base.colorScheme);
    final extras = base.extension<FlowThemeExtras>();

    // Las superficies elevadas (hojas, menus, dialogos) del tema base guardan
    // colores ya resueltos, asi que `copyWith(colorScheme:)` no las re-tine
    // sola: hay que repintarlas a mano o quedan grises sobre el negro azulado.
    // Van un escalon por encima del lienzo para despegarse de el, y opacas,
    // porque flotan sobre contenido arbitrario.
    final elevated = isDark ? const Color(0xFF16171E) : const Color(0xFFFFFFFF);

    return base.copyWith(
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      canvasColor: colors.surface,
      cardColor: colors.surfaceContainer,
      dividerTheme: DividerThemeData(color: colors.outlineVariant, space: 1),
      dividerColor: colors.outlineVariant,
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: elevated,
        modalBackgroundColor: elevated,
      ),
      popupMenuTheme: base.popupMenuTheme.copyWith(color: elevated),
      dialogTheme: base.dialogTheme.copyWith(backgroundColor: elevated),
      menuTheme: MenuThemeData(
        style: MenuStyle(backgroundColor: WidgetStatePropertyAll(elevated)),
      ),
      extensions: [
        if (extras != null)
          extras.copyWith(
            glassBackground: colors.surfaceContainer,
            subtleStroke: colors.outline,
          ),
      ],
    );
  }

  /// Texto terciario del diseno: `rgba(255,255,255,.4)` / `#9a9ba2`.
  static Color faint(ColorScheme colors) => colors.brightness == Brightness.dark
      ? const Color(0x66FFFFFF)
      : const Color(0xFF9A9BA2);

  /// Pista apagada de sliders y switches: `rgba(255,255,255,.18)` / `#d7d8dd`.
  static Color track(ColorScheme colors) => colors.brightness == Brightness.dark
      ? const Color(0x2EFFFFFF)
      : const Color(0xFFD7D8DD);

  static ColorScheme _darkScheme(ColorScheme base) => base.copyWith(
    surface: const Color(0xFF0C0D12),
    surfaceDim: const Color(0xFF080910),
    surfaceBright: const Color(0xFF16171E),
    // Rieles (barra superior y sidebar): mas oscuros que el lienzo.
    surfaceContainerLowest: const Color(0xFF0A0B0F),
    surfaceContainerLow: const Color(0xFF0E0F15),
    // Panel del diseno: blanco al 4.5% sobre el lienzo.
    surfaceContainer: const Color(0x0CFFFFFF),
    // Pastilla de busqueda y botones de icono: blanco al 7%.
    surfaceContainerHigh: const Color(0x12FFFFFF),
    surfaceContainerHighest: const Color(0x1AFFFFFF),
    onSurface: const Color(0xFFFFFFFF),
    onSurfaceVariant: const Color(0x94FFFFFF),
    outline: const Color(0x14FFFFFF),
    outlineVariant: const Color(0x0FFFFFFF),
  );

  static ColorScheme _lightScheme(ColorScheme base) => base.copyWith(
    surface: const Color(0xFFF4F5F7),
    surfaceDim: const Color(0xFFE9EAEE),
    surfaceBright: const Color(0xFFFFFFFF),
    surfaceContainerLowest: const Color(0xFFFFFFFF),
    surfaceContainerLow: const Color(0xFFFBFBFC),
    surfaceContainer: const Color(0xFFFFFFFF),
    surfaceContainerHigh: const Color(0xFFF1F2F5),
    surfaceContainerHighest: const Color(0xFFE9EAEE),
    onSurface: const Color(0xFF101014),
    onSurfaceVariant: const Color(0xFF6B6C75),
    outline: const Color(0xFFE8E9ED),
    outlineVariant: const Color(0xFFE9EAEE),
  );
}
