import 'package:flow_music/features/favorites/presentation/controllers/favorites_controller.dart';
import 'package:flow_music/features/playlists/presentation/controllers/playlists_controller.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_sync.dart';
import 'package:flow_music/features/youtube_account/presentation/controllers/youtube_music_account_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final youtubeMusicSyncControllerProvider =
    NotifierProvider<YouTubeMusicSyncController, bool>(
      YouTubeMusicSyncController.new,
    );

/// Resumen para el aviso al terminar.
class YouTubeMusicSyncSummary {
  const YouTubeMusicSyncSummary({
    required this.playlistsSaved,
    required this.favoritesAdded,
    required this.changesSent,
  });

  /// Listas de YouTube guardadas en el apartado «YouTube».
  final int playlistsSaved;

  /// «Me gusta» de YouTube que se sumaron a Favoritas.
  final int favoritesAdded;

  /// «Me gusta» y canciones de listas enviados a YouTube.
  final int changesSent;
}

/// Sincroniza favoritas y Biblioteca con la cuenta de YouTube Music. El
/// estado indica si hay una sincronizacion en curso.
class YouTubeMusicSyncController extends Notifier<bool> {
  @override
  bool build() => false;

  /// Devuelve null si ya habia una en curso o no hay cuenta conectada.
  Future<YouTubeMusicSyncSummary?> sync() async {
    final repository = ref.read(youtubeMusicAccountRepositoryProvider);
    if (state || repository == null) return null;
    state = true;
    try {
      final favorites = ref.read(favoritesControllerProvider);
      final playlists = ref.read(playlistsControllerProvider);
      final result = await YouTubeMusicSync(repository).run(
        favoriteIds: [for (final song in favorites) song.videoId],
        playlists: [
          for (final playlist in playlists)
            StreamBeatSyncList(
              name: playlist.name,
              // Los archivos sueltos sin video de YouTube no se pueden copiar.
              videoIds: [for (final audio in playlist.items) audio.videoId],
            ),
        ],
      );

      await ref
          .read(youtubeLibraryProvider.notifier)
          .replaceAll(result.library);
      final favoritesAdded = await _addLikedToFavorites(result);
      await ref
          .read(youtubeLastSyncProvider.notifier)
          .markSynced(DateTime.now());

      return YouTubeMusicSyncSummary(
        playlistsSaved: result.library.length,
        favoritesAdded: favoritesAdded,
        changesSent: result.likesSent + result.songsSent,
      );
    } finally {
      state = false;
    }
  }

  /// Suma a Favoritas los «Me gusta» de YouTube que no esten ya. Se agregan
  /// del mas antiguo al mas reciente para que queden en el orden de YouTube.
  Future<int> _addLikedToFavorites(YouTubeMusicSyncResult result) async {
    final favorites = ref.read(favoritesControllerProvider.notifier);
    var added = 0;
    for (final song in result.likedSongs.reversed) {
      if (favorites.isFavorite(song.videoId)) continue;
      await favorites.add(
        videoId: song.videoId,
        title: song.displayText,
        author: song.channelTitle,
        thumbnailUrl: song.thumbnailUrl,
      );
      added++;
    }
    return added;
  }
}
