import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/core/utils/search_text_normalizer.dart';
import 'package:flow_music/features/favorites/presentation/pages/radio_playlist_detail_page.dart';
import 'package:flow_music/features/home/presentation/providers/text_search.dart';
import 'package:flow_music/features/library/presentation/widgets/library_empty_card.dart';
import 'package:flow_music/features/library/presentation/widgets/library_radio_playlist_tile.dart';
import 'package:flow_music/features/library/presentation/widgets/library_section_header.dart';
import 'package:flow_music/features/radio/data/models/radio_playlist.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/presentation/controllers/radio_favorites_controller.dart';
import 'package:flow_music/features/radio/presentation/controllers/radio_playlists_controller.dart';
import 'package:flow_music/features/radio/presentation/utils/play_radio_station.dart';
import 'package:flow_music/features/radio/presentation/widgets/radio_playlist_actions.dart';
import 'package:flow_music/features/radio/presentation/widgets/radio_station_tile.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Biblioteca de la edición para tienda: conserva el diseño de biblioteca,
/// pero organiza solamente emisoras favoritas y listas de radio.
class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final favorites = ref.watch(radioFavoritesControllerProvider);
    final playlists = ref.watch(radioPlaylistsControllerProvider);
    final searchController = ref.watch(searchProvider);

    return ListenableBuilder(
      listenable: searchController,
      builder: (context, _) {
        final query = normalizeSearchText(searchController.text);
        final visibleFavorites = _filterStations(favorites, query);
        final visiblePlaylists = _filterPlaylists(playlists, query);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            LibrarySectionHeader(
              title: LocaleKeys.playlists.tr(),
              trailing: IconButton.filledTonal(
                onPressed: () =>
                    showCreateRadioPlaylistFlow(context: context, ref: ref),
                icon: const Icon(Icons.add_rounded),
                tooltip: LocaleKeys.new_radio_playlist.tr(),
              ),
            ),
            const SizedBox(height: 8),
            if (visiblePlaylists.isEmpty)
              LibraryEmptyCard(
                icon: Icons.queue_music_rounded,
                message: LocaleKeys.empty_radio_playlists.tr(),
                colors: colors,
              )
            else
              ...visiblePlaylists.map(
                (playlist) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LibraryRadioPlaylistTile(
                    name: playlist.name,
                    itemCount: playlist.itemCount,
                    onTap: () => _openPlaylist(context, playlist),
                    onDelete: () => ref
                        .read(radioPlaylistsControllerProvider.notifier)
                        .delete(playlist.id),
                  ),
                ),
              ),
            const SizedBox(height: 28),
            LibrarySectionHeader(
              title: LocaleKeys.favorite_stations.tr(),
              index: 1,
            ),
            const SizedBox(height: 12),
            if (visibleFavorites.isEmpty)
              LibraryEmptyCard(
                icon: Icons.radio_rounded,
                message: LocaleKeys.no_radio_favorites.tr(),
                colors: colors,
              )
            else
              ...visibleFavorites.indexed.map((entry) {
                final index = entry.$1;
                final station = entry.$2;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RadioStationTile(
                    station: station,
                    onTap: () => playRadioStation(
                      context: context,
                      ref: ref,
                      station: station,
                      queue: visibleFavorites,
                      index: index,
                    ),
                    onAddToPlaylist: () => showAddToRadioPlaylistFlow(
                      context: context,
                      ref: ref,
                      station: station,
                    ),
                    onRemove: () => ref
                        .read(radioFavoritesControllerProvider.notifier)
                        .remove(_stationKey(station)),
                    removeLabel: LocaleKeys.remove_from_favorites.tr(),
                  ),
                );
              }),
            const SizedBox(height: 28),
            LibraryEmptyCard(
              icon: Icons.cloud_queue_rounded,
              message: LocaleKeys.library_saved_on_device.tr(),
              colors: colors,
            ),
          ],
        );
      },
    );
  }

  static List<RadioStation> _filterStations(
    List<RadioStation> stations,
    String query,
  ) {
    if (query.isEmpty) return stations;
    return stations
        .where(
          (station) =>
              searchTextContains(station.name, query) ||
              searchTextContains(station.country, query) ||
              searchTextContains(station.tags, query),
        )
        .toList();
  }

  static List<RadioPlaylist> _filterPlaylists(
    List<RadioPlaylist> playlists,
    String query,
  ) {
    if (query.isEmpty) return playlists;
    return playlists
        .where((playlist) => searchTextContains(playlist.name, query))
        .toList();
  }

  static String _stationKey(RadioStation station) =>
      station.stationUuid.isEmpty ? station.streamUrl : station.stationUuid;

  static void _openPlaylist(BuildContext context, RadioPlaylist playlist) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RadioPlaylistDetailPage(playlistId: playlist.id),
      ),
    );
  }
}
