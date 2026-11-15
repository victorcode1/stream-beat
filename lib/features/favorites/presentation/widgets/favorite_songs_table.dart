import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/theme/desktop_theme.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/favorites/data/favorite_song.dart';
import 'package:flow_music/shared/widgets/playing_bars_indicator.dart';
import 'package:flutter/material.dart';

/// Listado de favoritos en tabla para escritorio.
///
/// El mockup "Favoritos — escritorio" cambia las tarjetas apiladas por una
/// tabla densa y numerada. Sus columnas son `# / Título / Álbum / duración`,
/// pero `FavoriteSong` solo guarda titulo, autor, miniatura y fecha: no hay
/// album ni duracion. En vez de dejar dos columnas vacias, la tercera muestra
/// cuando se agrego la cancion, que es dato real y ordena la lista.
class FavoriteSongsTable extends StatelessWidget {
  const FavoriteSongsTable({
    super.key,
    required this.songs,
    required this.padding,
    required this.onPlay,
    required this.onRemove,
    this.currentId,
    this.isPlaying = false,
  });

  /// Ancho de la columna de indice y de la columna derecha.
  static const double _indexWidth = 30;
  static const double _metaWidth = 150;
  static const double _columnGap = 16;

  final List<FavoriteSong> songs;
  final EdgeInsets padding;
  final void Function(int index) onPlay;
  final void Function(FavoriteSong song) onRemove;

  /// videoId de la cancion cargada en el reproductor.
  final String? currentId;

  /// El reproductor esta sonando (no en pausa).
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final headerStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: FlowDesktopTheme.faint(colors),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(padding.left, 0, padding.right, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.outlineVariant)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                children: [
                  SizedBox(
                    width: _indexWidth,
                    child: Text('#', style: headerStyle),
                  ),
                  const SizedBox(width: _columnGap),
                  Expanded(
                    child: Text(LocaleKeys.title.tr(), style: headerStyle),
                  ),
                  const SizedBox(width: _columnGap),
                  SizedBox(
                    width: _metaWidth,
                    child: Text(
                      LocaleKeys.added.tr(),
                      textAlign: TextAlign.right,
                      style: headerStyle,
                    ),
                  ),
                  // Hueco de la columna de acciones, para que la cabecera
                  // quede a plomo con las filas.
                  const SizedBox(width: 40),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
              padding.left,
              8,
              padding.right,
              padding.bottom,
            ),
            itemCount: songs.length,
            itemBuilder: (context, index) => _SongRow(
              song: songs[index],
              position: index + 1,
              isCurrent: songs[index].videoId == currentId,
              isPlaying: songs[index].videoId == currentId && isPlaying,
              onPlay: () => onPlay(index),
              onRemove: () => onRemove(songs[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _SongRow extends StatelessWidget {
  const _SongRow({
    required this.song,
    required this.position,
    required this.onPlay,
    required this.onRemove,
    required this.isCurrent,
    required this.isPlaying,
  });

  final FavoriteSong song;
  final int position;
  final VoidCallback onPlay;
  final VoidCallback onRemove;
  final bool isCurrent;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: FlowDesktopTheme.faint(colors),
    );

    return Material(
      color: isCurrent
          ? colors.primary.withValues(alpha: 0.10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPlay,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              SizedBox(
                width: FavoriteSongsTable._indexWidth,
                child: isCurrent
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: PlayingBarsIndicator(
                          isPlaying: isPlaying,
                          color: colors.primary,
                          size: 16,
                        ),
                      )
                    : Text(
                        '$position',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: FlowDesktopTheme.faint(colors),
                        ),
                      ),
              ),
              const SizedBox(width: FavoriteSongsTable._columnGap),
              Expanded(
                child: Row(
                  children: [
                    _RowArtwork(url: song.thumbnailUrl, color: colors.primary),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isCurrent
                                  ? colors.primary
                                  : colors.onSurface,
                            ),
                          ),
                          if (song.author.isNotEmpty)
                            Text(
                              song.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: FavoriteSongsTable._columnGap),
              SizedBox(
                width: FavoriteSongsTable._metaWidth,
                child: Text(
                  DateFormat.yMMMd(
                    context.locale.toString(),
                  ).format(song.addedAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: metaStyle,
                ),
              ),
              SizedBox(
                width: 40,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  tooltip: LocaleKeys.remove_from_favorites.tr(),
                  color: colors.onSurfaceVariant,
                  icon: const Icon(Icons.favorite_rounded),
                  onPressed: onRemove,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Miniatura de 42px con respaldo cuando la imagen no carga.
class _RowArtwork extends StatelessWidget {
  const _RowArtwork({required this.url, required this.color});

  final String url;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const size = 42.0;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.music_note_rounded, size: 20, color: color),
    );
    if (url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}
