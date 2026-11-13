import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/library/data/downloaded_audio.dart';
import 'package:flow_music/shared/widgets/song_row.dart';
import 'package:flutter/material.dart';

class LibraryDownloadedAudioTile extends StatelessWidget {
  const LibraryDownloadedAudioTile({
    super.key,
    required this.audio,
    required this.onTap,
    this.subtitle,
    this.fallbackSubtitle,
    this.deleteLabel,
    this.onAddToPlaylist,
    this.onShare,
    this.onShowLocation,
    this.onDelete,
  });

  final DownloadedAudio audio;
  final VoidCallback onTap;
  final String? subtitle;
  final String? fallbackSubtitle;
  final String? deleteLabel;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onShare;
  final VoidCallback? onShowLocation;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasMenu =
        onAddToPlaylist != null ||
        onShare != null ||
        onShowLocation != null ||
        onDelete != null;

    // Fila plana como la de los resultados: caratula con el radio del
    // estilo, sin tarjeta ni boton de reproducir (toda la fila reproduce).
    return SongRow(
      title: audio.title.isEmpty ? LocaleKeys.audio.tr() : audio.title,
      subtitle:
          subtitle ??
          (audio.author.isEmpty ? (fallbackSubtitle ?? '') : audio.author),
      artworkUrl: audio.thumbnailUrl,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      trailing: hasMenu ? _menu(colors) : null,
    );
  }

  Widget _menu(ColorScheme colors) {
    return PopupMenuButton<_DownloadAction>(
      tooltip: LocaleKeys.menu.tr(),
      icon: Icon(Icons.more_vert_rounded, color: colors.onSurfaceVariant),
      onSelected: (action) {
        switch (action) {
          case _DownloadAction.addToPlaylist:
            onAddToPlaylist?.call();
          case _DownloadAction.share:
            onShare?.call();
          case _DownloadAction.showLocation:
            onShowLocation?.call();
          case _DownloadAction.delete:
            onDelete?.call();
        }
      },
      itemBuilder: (context) => [
        if (onAddToPlaylist != null)
          PopupMenuItem(
            value: _DownloadAction.addToPlaylist,
            child: Row(
              children: [
                Icon(Icons.playlist_add_rounded, color: colors.primary),
                const SizedBox(width: 12),
                Text(LocaleKeys.add_to_playlist.tr()),
              ],
            ),
          ),
        if (onShare != null)
          PopupMenuItem(
            value: _DownloadAction.share,
            child: Row(
              children: [
                Icon(Icons.ios_share_rounded, color: colors.primary),
                const SizedBox(width: 12),
                Text(LocaleKeys.share.tr()),
              ],
            ),
          ),
        if (onShowLocation != null)
          PopupMenuItem(
            value: _DownloadAction.showLocation,
            child: Row(
              children: [
                Icon(Icons.folder_open_rounded, color: colors.primary),
                const SizedBox(width: 12),
                Text(LocaleKeys.view_file_location.tr()),
              ],
            ),
          ),
        if (onDelete != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: _DownloadAction.delete,
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded, color: colors.error),
                const SizedBox(width: 12),
                Text(
                  deleteLabel ?? LocaleKeys.delete_download.tr(),
                  style: TextStyle(color: colors.error),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

enum _DownloadAction { addToPlaylist, share, showLocation, delete }
