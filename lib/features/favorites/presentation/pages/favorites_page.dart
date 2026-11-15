import 'dart:async';
import 'dart:math' show Random;

import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/adaptive_layout.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/favorites/data/favorite_song.dart';
import 'package:flow_music/features/favorites/presentation/controllers/favorite_playback_controller.dart';
import 'package:flow_music/features/favorites/presentation/controllers/favorites_controller.dart';
import 'package:flow_music/features/favorites/presentation/controllers/favorites_page_controller.dart';
import 'package:flow_music/features/favorites/presentation/widgets/favorite_songs_tab.dart';
import 'package:flow_music/features/favorites/presentation/widgets/favorite_stations_tab.dart';
import 'package:flow_music/features/favorites/presentation/widgets/favorites_desktop_hero.dart';
import 'package:flow_music/features/favorites/presentation/widgets/favorites_page_shell.dart';
import 'package:flow_music/features/favorites/presentation/widgets/radio_playlists_tab.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Pantalla con tres pestañas de favoritos: canciones, emisoras y listas de
/// radios. Las canciones siguen funcionando exactamente igual; las dos nuevas
/// pestañas viven sobre los controllers de radio y se sincronizan con el
/// mismo ciclo que el resto del estado.
class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  static const _pageController = FavoritesPageController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesControllerProvider);

    return FavoritesPageShell(
      // El heroe del mockup solo cabe en escritorio; movil conserva su titulo.
      hero: useFlowDesktopShell(context)
          ? FavoritesDesktopHero(
              songCount: favorites.length,
              onPlayAll: () => _play(context, ref, favorites, 0),
              onShuffle: () => _play(
                context,
                ref,
                favorites,
                Random().nextInt(favorites.length),
              ),
            )
          : null,
      tabs: [
        Tab(text: LocaleKeys.favorites_tab_songs.tr()),
        Tab(text: LocaleKeys.favorites_tab_stations.tr()),
        Tab(text: LocaleKeys.favorites_tab_radio_playlists.tr()),
      ],
      tabViews: const [
        FavoriteSongsTab(pageController: _pageController),
        FavoriteStationsTab(pageController: _pageController),
        RadioPlaylistsTab(pageController: _pageController),
      ],
    );
  }

  /// Reproduce [index] dentro de la lista sin salir de Favoritos.
  static void _play(
    BuildContext context,
    WidgetRef ref,
    List<FavoriteSong> favorites,
    int index,
  ) {
    unawaited(
      ref.read(favoritePlaybackControllerProvider).play(favorites, index),
    );
  }
}
