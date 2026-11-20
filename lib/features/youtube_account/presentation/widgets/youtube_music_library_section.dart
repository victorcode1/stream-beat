import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/library/presentation/widgets/library_section_header.dart';
import 'package:flow_music/features/youtube_account/data/youtube_library_store.dart';
import 'package:flow_music/features/youtube_account/presentation/controllers/youtube_music_account_controller.dart';
import 'package:flow_music/features/youtube_account/presentation/controllers/youtube_music_sync_controller.dart';
import 'package:flow_music/features/youtube_account/presentation/pages/youtube_music_playlist_page.dart';
import 'package:flow_music/features/youtube_account/presentation/widgets/youtube_music_sync_action.dart';
import 'package:flow_music/shared/widgets/song_row.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Apartado «YouTube» de la Biblioteca: las listas de la cuenta guardadas en
/// el dispositivo. Conectar y desconectar viven en el avatar de la barra
/// superior; aqui solo aparece con una cuenta conectada.
class YouTubeMusicLibrarySection extends ConsumerWidget {
  const YouTubeMusicLibrarySection({super.key, required this.index});

  /// Posicion de la seccion en la Biblioteca (elige el color del encabezado).
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(youtubeMusicAccountControllerProvider) != null;
    if (!connected) return const SizedBox.shrink();

    final playlists = ref.watch(youtubeLibraryProvider);
    final syncing = ref.watch(youtubeMusicSyncControllerProvider);
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        LibrarySectionHeader(
          title: LocaleKeys.yt_library_title.tr(),
          index: index,
          trailing: IconButton.filledTonal(
            tooltip: LocaleKeys.yt_sync_action.tr(),
            onPressed: syncing ? null : () => syncYouTubeMusic(context, ref),
            icon: syncing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
        ),
        const SizedBox(height: 8),
        if (playlists.isEmpty)
          _SyncCard(syncing: syncing)
        else
          for (final saved in playlists)
            SongRow(
              title: saved.playlist.title,
              subtitle: saved.playlist.subtitle,
              artworkUrl: saved.playlist.thumbnailUrl,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: colors.onSurfaceVariant,
              ),
              onTap: () => _open(context, saved),
            ),
      ],
    );
  }

  void _open(BuildContext context, SavedYouTubePlaylist saved) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YouTubeMusicPlaylistPage(
          playlist: saved.playlist,
          savedTracks: saved.tracks,
        ),
      ),
    );
  }
}

/// Todavia no se ha sincronizado: invita a hacerlo.
class _SyncCard extends ConsumerWidget {
  const _SyncCard({required this.syncing});

  final bool syncing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.sync_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                LocaleKeys.yt_library_empty.tr(),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: syncing ? null : () => syncYouTubeMusic(context, ref),
              child: Text(LocaleKeys.yt_sync_short.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
