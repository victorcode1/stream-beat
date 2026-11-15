import 'package:flow_music/core/theme/custom_theme.dart';
import 'package:flow_music/features/radio/data/models/radio_playlist.dart';
import 'package:flow_music/features/radio/presentation/widgets/radio_playlist_actions.dart';
import 'package:flutter/material.dart';

/// Tile dismissible para una playlist de radios favorita.
class RadioPlaylistTile extends StatelessWidget {
  const RadioPlaylistTile({
    super.key,
    required this.playlist,
    required this.onTap,
    required this.onDelete,
  });

  final RadioPlaylist playlist;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final extras = theme.extension<FlowThemeExtras>();

    return Dismissible(
      key: ValueKey('radio-playlist-${playlist.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
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
              color: colors.surfaceContainerHigh,
              border: Border.all(color: extras?.subtleStroke ?? colors.outline),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: colors.primary.withValues(alpha: 0.16),
                  ),
                  child: Icon(Icons.radio_rounded, color: colors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        stationCountLabel(playlist.itemCount),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
