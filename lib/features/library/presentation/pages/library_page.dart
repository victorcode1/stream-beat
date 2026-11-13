import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/adaptive_layout.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/favorites/presentation/pages/radio_playlist_detail_page.dart';
import 'package:flow_music/features/home/presentation/providers/text_search.dart';
import 'package:flow_music/features/library/data/downloaded_audio.dart';
import 'package:flow_music/features/library/presentation/controllers/library_page_controller.dart';
import 'package:flow_music/features/library/presentation/pages/downloaded_audio_player_page.dart';
import 'package:flow_music/features/library/presentation/pages/library_playlist_detail_page.dart';
import 'package:flow_music/features/library/presentation/widgets/library_downloaded_audio_tile.dart';
import 'package:flow_music/features/library/presentation/widgets/library_empty_card.dart';
import 'package:flow_music/features/library/presentation/widgets/library_playlist_grid.dart';
import 'package:flow_music/features/library/presentation/widgets/library_playlist_tile.dart';
import 'package:flow_music/features/library/presentation/widgets/library_playlists_header.dart';
import 'package:flow_music/features/library/presentation/widgets/library_radio_playlist_tile.dart';
import 'package:flow_music/features/library/presentation/widgets/library_section_header.dart';
import 'package:flow_music/features/library/presentation/widgets/library_smart_playlist_actions.dart';
import 'package:flow_music/features/playlists/data/playlist.dart';
import 'package:flow_music/features/playlists/presentation/controllers/playlists_controller.dart';
import 'package:flow_music/features/radio/presentation/controllers/radio_favorites_controller.dart';
import 'package:flow_music/features/radio/presentation/controllers/radio_playlists_controller.dart';
import 'package:flow_music/features/radio/presentation/utils/play_radio_station.dart';
import 'package:flow_music/features/radio/presentation/widgets/radio_playlist_actions.dart';
import 'package:flow_music/features/radio/presentation/widgets/radio_station_tile.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  static const LibraryPageController pageController = LibraryPageController();

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  late Future<LibraryPageData> _libraryFuture;

  @override
  void initState() {
    super.initState();
    _libraryFuture = LibraryPage.pageController.loadLibraryData();
  }

  Future<void> _reload() async {
    setState(() {
      _libraryFuture = LibraryPage.pageController.loadLibraryData();
    });
    await _libraryFuture;
  }

  void _openPlayer(DownloadedAudio audio) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DownloadedAudioPlayerPage(downloadedAudio: audio),
      ),
    );
  }

  void _openPlaylist(Playlist playlist) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LibraryPlaylistDetailPage(playlistId: playlist.id),
      ),
    );
  }

  Future<void> _createPlaylist({DownloadedAudio? firstAudio}) {
    return LibraryPage.pageController.createPlaylist(
      context: context,
      ref: ref,
      firstAudio: firstAudio,
    );
  }

  Future<void> _createSmartPlaylist(SmartPlaylistKind kind) {
    return LibraryPage.pageController.createSmartPlaylist(
      context: context,
      ref: ref,
      kind: kind,
    );
  }

  Future<void> _importPlaylist() {
    return LibraryPage.pageController.importPlaylist(
      context: context,
      ref: ref,
    );
  }

  Future<void> _showAddToPlaylist(DownloadedAudio audio) {
    return LibraryPage.pageController.showAddToPlaylist(
      context: context,
      ref: ref,
      audio: audio,
    );
  }

  Future<void> _shareAudio(DownloadedAudio audio) {
    return LibraryPage.pageController.shareAudio(
      context: context,
      audio: audio,
    );
  }

  Future<void> _showFileLocation(DownloadedAudio audio) {
    return LibraryPage.pageController.showFileLocation(
      context: context,
      audio: audio,
    );
  }

  Future<void> _confirmDelete(DownloadedAudio audio) {
    return LibraryPage.pageController.confirmDelete(
      context: context,
      audio: audio,
      onDeleted: _reload,
    );
  }

  Future<void> _confirmDeleteOffline(DownloadedAudio audio) {
    return LibraryPage.pageController.confirmDeleteOffline(
      context: context,
      audio: audio,
      onDeleted: _reload,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDesktop = useFlowDesktopShell(context);
    final playlists = ref.watch(playlistsControllerProvider);
    final radioFavorites = ref.watch(radioFavoritesControllerProvider);
    final radioPlaylists = ref.watch(radioPlaylistsControllerProvider);
    final searchController = ref.watch(searchProvider);

    return FutureBuilder<LibraryPageData>(
      future: _libraryFuture,
      builder: (context, snapshot) {
        final libraryData = snapshot.data ?? LibraryPageData.empty;
        final downloads = libraryData.downloads;
        final offlineAudios = libraryData.offlineAudios;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          );
        }

        return ListenableBuilder(
          listenable: searchController,
          builder: (context, _) {
            final query = searchController.text;
            final visiblePlaylists = LibraryPage.pageController.filterPlaylists(
              playlists,
              query,
            );
            final visibleDownloads = LibraryPage.pageController.filterAudios(
              downloads,
              query,
            );
            final visibleOffline = LibraryPage.pageController.filterAudios(
              offlineAudios,
              query,
            );
            final visibleRadioFavorites = LibraryPage.pageController
                .filterRadioFavorites(radioFavorites, query);
            final visibleRadioPlaylists = LibraryPage.pageController
                .filterRadioPlaylists(radioPlaylists, query);

            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                // El escritorio respira con el margen del diseno (30/40px); en
                // movil se mantiene el margen compacto de siempre.
                padding: isDesktop
                    ? const EdgeInsets.fromLTRB(40, 30, 40, 40)
                    : const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  LibraryPlaylistsHeader(
                    onCreate: () => _createPlaylist(),
                    onImport: _importPlaylist,
                  ),
                  const SizedBox(height: 10),
                  LibrarySmartPlaylistActions(onCreate: _createSmartPlaylist),
                  const SizedBox(height: 12),
                  // En escritorio las listas van en cuadricula de cubiertas
                  // (mockup "Biblioteca — escritorio"); en movil siguen siendo
                  // filas, que es lo que cabe a 390px.
                  if (isDesktop)
                    LibraryPlaylistGrid(
                      playlists: visiblePlaylists,
                      onOpen: _openPlaylist,
                      onCreate: () => _createPlaylist(),
                    )
                  else if (visiblePlaylists.isEmpty)
                    LibraryEmptyCard(
                      icon: Icons.playlist_add_rounded,
                      message: LocaleKeys.empty_playlists.tr(),
                      colors: colors,
                    )
                  else
                    ...visiblePlaylists.map(
                      (playlist) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: LibraryPlaylistTile(
                          playlist: playlist,
                          onTap: () => _openPlaylist(playlist),
                          onShare: () => LibraryPage.pageController
                              .sharePlaylist(playlist),
                          onDelete: () => ref
                              .read(playlistsControllerProvider.notifier)
                              .delete(playlist.id),
                        ),
                      ),
                    ),
                  const SizedBox(height: 28),
                  LibrarySectionHeader(
                    title: LocaleKeys.favorite_stations.tr(),
                    index: 1,
                    trailing: IconButton.filledTonal(
                      onPressed: () => showCreateRadioPlaylistFlow(
                        context: context,
                        ref: ref,
                      ),
                      icon: const Icon(Icons.add_rounded),
                      tooltip: LocaleKeys.new_radio_playlist.tr(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (visibleRadioFavorites.isEmpty)
                    LibraryEmptyCard(
                      icon: Icons.radio_rounded,
                      message: LocaleKeys.no_radio_favorites.tr(),
                      colors: colors,
                    )
                  else
                    ...visibleRadioFavorites.indexed.map((entry) {
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
                            queue: visibleRadioFavorites,
                            index: index,
                          ),
                          onAddToPlaylist: () => showAddToRadioPlaylistFlow(
                            context: context,
                            ref: ref,
                            station: station,
                          ),
                          onRemove: () => ref
                              .read(radioFavoritesControllerProvider.notifier)
                              .remove(
                                LibraryPage.pageController.radioStationKey(
                                  station,
                                ),
                              ),
                          removeLabel: LocaleKeys.remove_from_favorites.tr(),
                        ),
                      );
                    }),
                  const SizedBox(height: 28),
                  LibrarySectionHeader(
                    title: LocaleKeys.radio_playlists.tr(),
                    index: 2,
                  ),
                  const SizedBox(height: 12),
                  if (visibleRadioPlaylists.isEmpty)
                    LibraryEmptyCard(
                      icon: Icons.queue_music_rounded,
                      message: LocaleKeys.empty_radio_playlists.tr(),
                      colors: colors,
                    )
                  else
                    ...visibleRadioPlaylists.map(
                      (playlist) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: LibraryRadioPlaylistTile(
                          name: playlist.name,
                          itemCount: playlist.itemCount,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RadioPlaylistDetailPage(
                                playlistId: playlist.id,
                              ),
                            ),
                          ),
                          onDelete: () => ref
                              .read(radioPlaylistsControllerProvider.notifier)
                              .delete(playlist.id),
                        ),
                      ),
                    ),
                  const SizedBox(height: 28),
                  LibrarySectionHeader(
                    title: LocaleKeys.offline_library.tr(),
                    index: 3,
                  ),
                  const SizedBox(height: 8),
                  if (visibleOffline.isEmpty)
                    LibraryEmptyCard(
                      icon: Icons.offline_bolt_rounded,
                      message: LocaleKeys.no_offline_files.tr(),
                      colors: colors,
                    )
                  else
                    ...visibleOffline.map(
                      (audio) => LibraryDownloadedAudioTile(
                        audio: audio,
                        subtitle: LocaleKeys.offline_available.tr(),
                        deleteLabel: LocaleKeys.remove_offline.tr(),
                        onTap: () => _openPlayer(audio),
                        onAddToPlaylist: () => _showAddToPlaylist(audio),
                        onDelete: () => _confirmDeleteOffline(audio),
                      ),
                    ),
                  const SizedBox(height: 28),
                  LibrarySectionHeader(
                    title: LocaleKeys.downloaded_files.tr(),
                    index: 4,
                  ),
                  const SizedBox(height: 8),
                  if (visibleDownloads.isEmpty)
                    LibraryEmptyCard(
                      icon: Icons.folder_off_rounded,
                      message: LocaleKeys.no_downloaded_files.tr(),
                      colors: colors,
                    )
                  else
                    ...visibleDownloads.map(
                      (audio) => LibraryDownloadedAudioTile(
                        audio: audio,
                        onTap: () => _openPlayer(audio),
                        fallbackSubtitle: LibraryPage.pageController
                            .mediaTypeLabel(audio),
                        onAddToPlaylist: () => _showAddToPlaylist(audio),
                        onShare: () => _shareAudio(audio),
                        onShowLocation: () => _showFileLocation(audio),
                        onDelete: () => _confirmDelete(audio),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
