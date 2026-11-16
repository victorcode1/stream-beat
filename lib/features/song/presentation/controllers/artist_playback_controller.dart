import 'package:flow_music/core/audio/background_audio_handler.dart';
import 'package:flow_music/features/autoplay/presentation/controllers/autoplay_queue_controller.dart';
import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/features/song/presentation/controllers/song_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final artistPlaybackControllerProvider = Provider(ArtistPlaybackController.new);

/// Reproduce la lista visible del artista con la misma cola cerrada de favoritos.
class ArtistPlaybackController {
  ArtistPlaybackController(this.ref);

  final Ref ref;

  Future<void> play(
    List<YouTubeSearchSuggestion> songs,
    int index, {
    required bool isPlaying,
  }) async {
    if (index < 0 || index >= songs.length) return;
    final song = songs[index];
    if (song.videoId.isEmpty) return;
    final controller = ref.read(songController);
    final queue = ref.read(autoplayQueueControllerProvider.notifier);
    queue.enqueue(songs, index, collection: true);
    if (controller.currentVideoId == song.videoId) {
      if (controller.isLoading) return;
      await (isPlaying ? flowAudioHandler.pause() : flowAudioHandler.play());
      return;
    }

    controller.preloadMetadata(
      videoId: song.videoId,
      title: song.displayText,
      author: song.channelTitle,
      thumbnailUrl: song.thumbnailUrl,
    );
    await controller.autoPlay(id: song.videoId, knownDuration: song.duration);
  }
}
