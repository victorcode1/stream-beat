import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/favorites/presentation/controllers/favorites_page_controller.dart';
import 'package:flow_music/features/favorites/presentation/widgets/favorites_empty_state.dart';
import 'package:flow_music/features/home/presentation/providers/text_search.dart';
import 'package:flow_music/features/radio/data/station_removals_repository.dart';
import 'package:flow_music/features/radio/presentation/controllers/radio_favorites_controller.dart';
import 'package:flow_music/features/radio/presentation/utils/play_radio_station.dart';
import 'package:flow_music/features/radio/presentation/widgets/add_station_dialog.dart';
import 'package:flow_music/features/radio/presentation/widgets/radio_playlist_actions.dart';
import 'package:flow_music/features/radio/presentation/widgets/radio_station_tile.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Pestaña que muestra emisoras favoritas filtradas por la búsqueda global.
class FavoriteStationsTab extends ConsumerWidget {
  const FavoriteStationsTab({super.key, required this.pageController});

  final FavoritesPageController pageController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final stations = ref.watch(radioFavoritesControllerProvider);
    final controller = ref.read(radioFavoritesControllerProvider.notifier);
    final searchController = ref.watch(searchProvider);

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: FilledButton.tonalIcon(
              onPressed: () => showAddStationDialog(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: Text(LocaleKeys.station_add.tr()),
            ),
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: searchController,
            builder: (context, _) {
              final visible = pageController.filterStations(
                stations
                    .where(
                      (station) => !StationRemovalsRepository.instance.current
                          .contains(station),
                    )
                    .toList(),
                searchController.text,
              );

              if (visible.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  child: FavoritesEmptyState(
                    icon: Icons.radio_rounded,
                    message: LocaleKeys.no_radio_favorites.tr(),
                    colors: colors,
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: visible.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final station = visible[index];
                  return RadioStationTile(
                    station: station,
                    onTap: () => playRadioStation(
                      context: context,
                      ref: ref,
                      station: station,
                      queue: visible,
                      index: index,
                    ),
                    onAddToPlaylist: () => showAddToRadioPlaylistFlow(
                      context: context,
                      ref: ref,
                      station: station,
                    ),
                    onRemove: () => pageController.removeStation(
                      context: context,
                      controller: controller,
                      station: station,
                    ),
                    removeLabel: LocaleKeys.remove_from_favorites.tr(),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
