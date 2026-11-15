import 'package:flow_music/features/autoplay/presentation/controllers/autoplay_queue_controller.dart';
import 'package:flow_music/features/favorites/data/favorite_song.dart';
import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/features/song/presentation/controllers/song_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final favoritePlaybackControllerProvider = Provider(
  FavoritePlaybackController.new,
);

/// Inicia una lista cerrada sin cambiar la seccion que el usuario esta viendo.
class FavoritePlaybackController {
  FavoritePlaybackController(this.ref);

  final Ref ref;

  Future<void> play(List<FavoriteSong> songs, int index) async {
    if (index < 0 || index >= songs.length) return;
    final song = songs[index];
    ref
        .read(autoplayQueueControllerProvider.notifier)
        .enqueue(
          songs
              .map(
                (song) => YouTubeSearchSuggestion(
                  videoId: song.videoId,
                  displayText: song.title,
                  channelTitle: song.author,
                  thumbnailUrl: song.thumbnailUrl,
                ),
              )
              .toList(growable: false),
          index,
          collection: true,
        );
    final controller = ref.read(songController);
    controller.preloadMetadata(
      videoId: song.videoId,
      title: song.title,
      author: song.author,
      thumbnailUrl: song.thumbnailUrl,
    );
    await controller.autoPlay(id: song.videoId);
  }
}
