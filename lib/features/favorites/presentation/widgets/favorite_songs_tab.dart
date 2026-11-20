import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/audio/now_playing_provider.dart';
import 'package:flow_music/core/utils/adaptive_layout.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/favorites/presentation/controllers/favorite_playback_controller.dart';
import 'package:flow_music/features/favorites/presentation/controllers/favorites_controller.dart';
import 'package:flow_music/features/favorites/presentation/controllers/favorites_page_controller.dart';
import 'package:flow_music/features/favorites/presentation/widgets/favorite_song_tile.dart';
import 'package:flow_music/features/favorites/presentation/widgets/favorite_songs_table.dart';
import 'package:flow_music/features/favorites/presentation/widgets/favorites_empty_state.dart';
import 'package:flow_music/features/home/presentation/providers/text_search.dart';
import 'package:flow_music/features/song/presentation/utils/open_song_view.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Pestaña que muestra las canciones favoritas filtradas por la búsqueda global.
class FavoriteSongsTab extends ConsumerWidget {
  const FavoriteSongsTab({super.key, required this.pageController});

  final FavoritesPageController pageController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final favorites = ref.watch(favoritesControllerProvider);
    final controller = ref.read(favoritesControllerProvider.notifier);
    final searchController = ref.watch(searchProvider);
    final currentId = ref.watch(nowPlayingIdProvider).value;
    final isPlaying = ref.watch(nowPlayingIsPlayingProvider).value ?? false;

    return ListenableBuilder(
      listenable: searchController,
      builder: (context, _) {
        final visible = pageController.filterSongs(
          favorites,
          searchController.text,
        );

        if (visible.isEmpty) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              flowContentInset(context),
              16,
              flowContentInset(context),
              flowListBottomInset(context),
            ),
            child: FavoritesEmptyState(
              icon: Icons.favorite_border_rounded,
              message: LocaleKeys.no_favorites.tr(),
              colors: colors,
            ),
          );
        }

        // Tocar la cancion que ya suena la pausa o reanuda; no la reinicia.
        // Otra cancion abre su vista en movil; el escritorio ya la muestra en
        // la barra inferior y solo la reproduce.
        void play(int index) {
          final playback = ref.read(favoritePlaybackControllerProvider);
          if (visible[index].videoId == currentId) {
            unawaited(playback.togglePlayback(isPlaying: isPlaying));
          } else if (useFlowDesktopShell(context)) {
            unawaited(playback.play(visible, index));
          } else if (playback.queue(visible, index) case final song?) {
            unawaited(openSongView(context, song));
          }
        }

        // En escritorio, tabla densa numerada (mockup "Favoritos —
        // escritorio"); en movil, las tarjetas de siempre.
        if (useFlowDesktopShell(context)) {
          return FavoriteSongsTable(
            songs: visible,
            currentId: currentId,
            isPlaying: isPlaying,
            padding: EdgeInsets.fromLTRB(
              flowContentInset(context),
              0,
              flowContentInset(context),
              flowListBottomInset(context),
            ),
            onPlay: play,
            onRemove: (song) => controller.remove(song.videoId),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            flowContentInset(context),
            12,
            flowContentInset(context),
            flowListBottomInset(context),
          ),
          itemCount: visible.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final favorite = visible[index];
            final isCurrent = favorite.videoId == currentId;
            return FavoriteSongTile(
              favorite: favorite,
              isCurrent: isCurrent,
              isPlaying: isCurrent && isPlaying,
              onTap: () => play(index),
              onRemove: () => controller.remove(favorite.videoId),
            );
          },
        );
      },
    );
  }
}
