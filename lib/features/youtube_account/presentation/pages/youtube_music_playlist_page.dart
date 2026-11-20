import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/audio/now_playing_provider.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/library/presentation/widgets/library_empty_card.dart';
import 'package:flow_music/features/song/presentation/controllers/artist_playback_controller.dart';
import 'package:flow_music/features/song/presentation/controllers/song_controller.dart';
import 'package:flow_music/features/song/presentation/utils/open_song_view.dart';
import 'package:flow_music/features/song/presentation/widgets/artist_song_tile.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_library_parser.dart';
import 'package:flow_music/features/youtube_account/presentation/controllers/youtube_music_account_controller.dart';
import 'package:flow_music/features/youtube_account/presentation/widgets/youtube_music_sync_action.dart';
import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Canciones de una lista de la cuenta. Tocar una reproduce la lista entera
/// como cola cerrada, igual que la lista de un artista.
///
/// Con [savedTracks] (apartado «YouTube») muestra la copia guardada en el
/// dispositivo, que se actualiza al sincronizar; sin ellas pide la lista a
/// YouTube (filas del Inicio).
class YouTubeMusicPlaylistPage extends ConsumerWidget {
  const YouTubeMusicPlaylistPage({
    super.key,
    required this.playlist,
    this.savedTracks,
  });

  final YouTubeMusicPlaylist playlist;
  final List<YouTubeSearchSuggestion>? savedTracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = youtubeMusicPlaylistTracksProvider(playlist.id);
    final saved = savedTracks;
    final tracks = saved == null
        ? ref.watch(provider)
        : AsyncValue.data(
            ref.watch(
                  youtubeLibraryProvider.select(
                    (library) => library
                        .where((entry) => entry.playlist.id == playlist.id)
                        .firstOrNull
                        ?.tracks,
                  ),
                ) ??
                saved,
          );
    final currentId = ref.watch(
      songController.select((controller) => controller.currentVideoId),
    );
    final isPlaying = ref.watch(nowPlayingIsPlayingProvider).value ?? false;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          playlist.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: tracks.when(
        loading: () => const Center(
          child: CircularProgressIndicator.adaptive(strokeWidth: 2),
        ),
        error: (_, _) => _LoadError(onRetry: () => ref.invalidate(provider)),
        data: (songs) {
          if (songs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: LibraryEmptyCard(
                icon: Icons.queue_music_rounded,
                message: LocaleKeys.empty_playlist.tr(),
                colors: colors,
                minHeight: 220,
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => saved == null
                ? ref.refresh(provider.future)
                : syncYouTubeMusic(context, ref),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              itemCount: songs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final song = songs[index];
                final isCurrent = song.videoId == currentId;
                return ArtistSongTile(
                  song: song,
                  isCurrent: isCurrent,
                  isPlaying: isCurrent && isPlaying,
                  onTap: () {
                    final playback = ref.read(artistPlaybackControllerProvider);
                    // La que ya suena se pausa o reanuda; otra abre su vista.
                    if (isCurrent) {
                      unawaited(
                        playback.play(songs, index, isPlaying: isPlaying),
                      );
                      return;
                    }
                    playback.queue(songs, index);
                    unawaited(openSongView(context, song));
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              LocaleKeys.yt_account_load_error.tr(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onRetry,
              child: Text(LocaleKeys.retry.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
