import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tema del reproductor: siempre oscuro sobre la portada, sea cual sea el
/// estilo o la apariencia elegidos.
ThemeData playerOnDarkTheme(ThemeData theme) {
  final colors = theme.colorScheme;
  const surface = Color(0xFF0B0B0C);
  return theme.copyWith(
    brightness: Brightness.dark,
    // Los estilos claros traen el color del texto fijado en negro; sin esto el
    // titulo de la cancion quedaba oscuro sobre el fondo oscuro.
    textTheme: theme.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    iconTheme: theme.iconTheme.copyWith(color: Colors.white),
    appBarTheme: theme.appBarTheme.copyWith(
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    colorScheme: colors.copyWith(
      brightness: Brightness.dark,
      surface: surface,
      onSurface: Colors.white,
      onSurfaceVariant: Colors.white.withValues(alpha: 0.72),
      surfaceContainerHighest: Colors.white.withValues(alpha: 0.12),
      outlineVariant: Colors.white.withValues(alpha: 0.1),
    ),
  );
}
