import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'track_change_transition.dart';

/// Version sin franjas negras de una miniatura de YouTube.
///
/// `hqdefault` es 4:3 con el cuadro 16:9 dentro, asi que trae bandas negras
/// arriba y abajo. `maxresdefault` es el mismo cuadro a 1280×720 sin bandas.
/// Si un video no la tiene, [PlayerArtworkImage] vuelve a la original.
String playerArtworkUrl(String url) {
  final match = RegExp(
    r'(/vi(?:_webp)?/[^/]+/)(?:hq|mq|sd)?default\.(jpg|webp)',
  ).firstMatch(url);
  if (match == null) return url;
  return url.replaceRange(
    match.start,
    match.end,
    '${match.group(1)}maxresdefault.${match.group(2)}',
  );
}

/// Imagen de la caratula en alta resolucion, con la miniatura original de
/// respaldo.
class PlayerArtworkImage extends StatelessWidget {
  const PlayerArtworkImage({
    super.key,
    required this.url,
    required this.fallback,
    this.cacheWidth,
  });

  final String url;
  final Widget fallback;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final upgraded = playerArtworkUrl(url);
    Widget original() => Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => fallback,
    );
    if (upgraded == url) return original();
    return Image.network(
      upgraded,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => original(),
    );
  }
}

/// Fondo de la pantalla: la caratula muy desenfocada y oscurecida, para que
/// todo el reproductor tome el color de la cancion, como en Shazam.
class PlayerAmbientBackground extends StatelessWidget {
  const PlayerAmbientBackground({super.key, required this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    final url = thumbnailUrl ?? '';
    const base = ColoredBox(color: Color(0xFF0B0F14));
    return Stack(
      fit: StackFit.expand,
      children: [
        base,
        if (url.isNotEmpty)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: ImageFiltered(
              key: ValueKey(url),
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              // Una version pequena basta para un fondo desenfocado.
              child: PlayerArtworkImage(
                url: url,
                cacheWidth: 200,
                fallback: base,
              ),
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x8C000000), Color(0xD9000000)],
            ),
          ),
        ),
      ],
    );
  }
}

/// Caratula a todo lo ancho que se funde por abajo con el fondo ambiental.
class ModernPlayerHero extends StatelessWidget {
  const ModernPlayerHero({
    super.key,
    required this.thumbnailUrl,
    required this.trackKey,
    required this.forward,
    required this.isBusy,
    required this.placeholder,
  });

  final String? thumbnailUrl;
  final String trackKey;
  final bool forward;

  /// La pista nueva aun se esta abriendo: se atenua y muestra el indicador.
  final bool isBusy;
  final Widget placeholder;

  @override
  Widget build(BuildContext context) {
    final url = thumbnailUrl ?? '';
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedOpacity(
          duration: const Duration(milliseconds: 260),
          opacity: isBusy ? 0.5 : 1,
          child: ShaderMask(
            // Deja la imagen opaca arriba y la vuelve transparente abajo, asi
            // se funde con el fondo sin importar su color.
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.62, 1],
              colors: [Colors.white, Colors.white, Colors.transparent],
            ).createShader(bounds),
            child: TrackChangeTransition(
              trackKey: trackKey.isNotEmpty ? trackKey : url,
              forward: forward,
              expandToParent: true,
              child: url.isEmpty
                  ? placeholder
                  : PlayerArtworkImage(url: url, fallback: placeholder),
            ),
          ),
        ),
        if (isBusy)
          Center(
            child: SizedBox.square(
              dimension: 34,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}

/// Tema de texto claro para el reproductor sobre el fondo oscuro.
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
