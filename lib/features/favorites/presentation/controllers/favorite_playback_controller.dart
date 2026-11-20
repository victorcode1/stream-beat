import 'package:flow_music/core/audio/background_audio_handler.dart';
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
    final song = queue(songs, index);
    if (song == null) return;
    await ref.read(songController).autoPlay(id: song.videoId);
  }

  /// Deja la lista en cola centrada en [index] y precarga sus datos, sin
  /// arrancar el audio: lo arranca la vista de la cancion al abrirse.
  YouTubeSearchSuggestion? queue(List<FavoriteSong> songs, int index) {
    if (index < 0 || index >= songs.length) return null;
    final suggestions = songs
        .map(
          (song) => YouTubeSearchSuggestion(
            videoId: song.videoId,
            displayText: song.title,
            channelTitle: song.author,
            thumbnailUrl: song.thumbnailUrl,
          ),
        )
        .toList(growable: false);
    final song = suggestions[index];
    ref
        .read(autoplayQueueControllerProvider.notifier)
        .enqueue(suggestions, index, collection: true);
    ref
        .read(songController)
        .preloadMetadata(
          videoId: song.videoId,
          title: song.displayText,
          author: song.channelTitle,
          thumbnailUrl: song.thumbnailUrl,
        );
    return song;
  }

  /// Pausa o reanuda la cancion activa sin reiniciarla.
  Future<void> togglePlayback({required bool isPlaying}) {
    return isPlaying ? flowAudioHandler.pause() : flowAudioHandler.play();
  }
}
