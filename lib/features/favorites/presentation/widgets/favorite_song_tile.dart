import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/theme/custom_theme.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/favorites/data/favorite_song.dart';
import 'package:flow_music/shared/widgets/playing_bars_indicator.dart';
import 'package:flutter/material.dart';

/// Tile dismissible para una cancion marcada como favorita.
///
/// La que esta cargada en el reproductor se resalta: fondo teñido y borde con
/// el acento, titulo en rojo, barras animadas sobre la caratula y el boton
/// pasa a pausa/reanudar (mismo lenguaje que `SongRow` en busqueda).
class FavoriteSongTile extends StatelessWidget {
  const FavoriteSongTile({
    super.key,
    required this.favorite,
    required this.onTap,
    required this.onRemove,
    this.isCurrent = false,
    this.isPlaying = false,
  });

  final FavoriteSong favorite;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  /// Es la cancion activa del reproductor.
  final bool isCurrent;

  /// La cancion activa esta sonando (no en pausa).
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final extras = theme.extension<FlowThemeExtras>();
    final isDark = theme.brightness == Brightness.dark;
    final background = isCurrent
        ? Color.alphaBlend(
            colors.primary.withValues(alpha: 0.12),
            colors.surfaceContainerHigh,
          )
        : colors.surfaceContainerHigh;
    final border = isCurrent
        ? Border.all(color: colors.primary.withValues(alpha: 0.6), width: 1.5)
        : Border.all(color: extras?.subtleStroke ?? colors.outline);

    return Dismissible(
      key: ValueKey('fav-${favorite.videoId}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: colors.errorContainer,
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: colors.onErrorContainer,
        ),
      ),
      // Material propio: sin el, `Ink` pinta en el del Scaffold y su
      // fondo se sale de la lista (se veia detras del app bar).
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: background,
              border: border,
              boxShadow: [
                BoxShadow(
                  color: colors.scrim.withValues(alpha: isDark ? 0.4 : 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox.square(
                    dimension: 58,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (favorite.thumbnailUrl.isEmpty)
                          _FavoriteSongPlaceholder(colors: colors)
                        else
                          Image.network(
                            favorite.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) {
                              return _FavoriteSongPlaceholder(colors: colors);
                            },
                          ),
                        if (isCurrent)
                          ColoredBox(
                            color: Colors.black.withValues(alpha: 0.45),
                            child: Center(
                              child: PlayingBarsIndicator(
                                isPlaying: isPlaying,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        favorite.title.isEmpty
                            ? LocaleKeys.audio.tr()
                            : favorite.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: isCurrent ? colors.primary : null,
                        ),
                      ),
                      if (favorite.author.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          favorite.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  onPressed: onTap,
                  icon: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  tooltip: isPlaying
                      ? LocaleKeys.pause.tr()
                      : LocaleKeys.play.tr(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoriteSongPlaceholder extends StatelessWidget {
  const _FavoriteSongPlaceholder({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.music_note_rounded, color: colors.primary),
    );
  }
}
