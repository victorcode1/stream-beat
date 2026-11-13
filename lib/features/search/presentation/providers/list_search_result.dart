import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/features/search/data/repositories/youtube_suggestions_repository.dart';
import 'package:flow_music/features/song/presentation/controllers/song_controller.dart';
import 'package:flow_music/features/settings/presentation/controllers/default_playback_mode_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'list_search_result.g.dart';

@Riverpod(keepAlive: true)
Future<List<YouTubeSearchSuggestion>> searchResultData(
  Ref ref,
  String search,
) async {
  final query = search.trim();
  final playbackMode = ref.watch(defaultPlaybackModeControllerProvider);
  if (query.isEmpty) return const [];
  return searchSongsAndVideos(
    query,
    includeMusic: playbackMode == PlaybackMode.audio,
  );
}
