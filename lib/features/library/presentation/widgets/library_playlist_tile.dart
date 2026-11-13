import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/theme/visual_style.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/playlists/data/playlist.dart';
import 'package:flow_music/features/playlists/presentation/widgets/playlist_actions.dart';
import 'package:flutter/material.dart';

class LibraryPlaylistTile extends StatelessWidget {
  const LibraryPlaylistTile({
    super.key,
    required this.playlist,
    required this.onTap,
    required this.onShare,
    required this.onDelete,
  });

  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final radius = context.styleTokens.cardRadius.clamp(0.0, 16.0);

    return Dismissible(
      key: ValueKey('playlist-${playlist.id}'),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        // Fila plana, igual que las canciones: sin tarjeta ni borde.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  color: colors.primary.withValues(alpha: 0.16),
                ),
                child: Icon(Icons.queue_music_rounded, color: colors.primary),
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
                      songCountLabel(playlist.itemCount),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: LocaleKeys.share.tr(),
                onPressed: onShare,
                icon: Icon(
                  Icons.ios_share_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
