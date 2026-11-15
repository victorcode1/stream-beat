import 'package:flow_music/features/autoplay/data/shared_youtube_client.dart';
import 'package:flow_music/features/favorites/data/favorites_repository.dart';
import 'package:flow_music/features/history/data/playback_history_repository.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'downloaded_audio.dart';

bool _missingTitle(DownloadedAudio audio) =>
    audio.title.trim().isEmpty || audio.title == audio.videoId;

DownloadedAudio _merge(
  DownloadedAudio audio,
  String title,
  String author,
  String artwork,
) {
  final repaired = audio.copyWith(
    title: _missingTitle(audio) && title.isNotEmpty && title != audio.videoId
        ? title
        : null,
    author: audio.author.isEmpty && author.isNotEmpty ? author : null,
    thumbnailUrl: audio.thumbnailUrl.isEmpty && artwork.isNotEmpty
        ? artwork
        : null,
  );
  return repaired.title == audio.title &&
          repaired.author == audio.author &&
          repaired.thumbnailUrl == audio.thumbnailUrl
      ? audio
      : repaired;
}

/// Recupera datos locales antes de consultar la red; conserva el archivo y su fecha.
DownloadedAudio recoverLocalDownloadMetadata(DownloadedAudio audio) {
  if (audio.videoId.isEmpty) return audio;
  var result = audio;
  if (Hive.isBoxOpen(favoritesBoxName)) {
    for (final song in const FavoritesRepository().readAll()) {
      if (song.videoId == audio.videoId) {
        result = _merge(result, song.title, song.author, song.thumbnailUrl);
      }
    }
  }
  if (Hive.isBoxOpen(playbackHistoryBoxName)) {
    for (final song in const PlaybackHistoryRepository().readAll()) {
      if (song.id == audio.videoId) {
        result = _merge(result, song.title, song.subtitle, song.thumbnailUrl);
      }
    }
  }
  return result;
}

Future<DownloadedAudio> recoverDownloadMetadata(DownloadedAudio audio) async {
  final local = recoverLocalDownloadMetadata(audio);
  if (local.videoId.isEmpty ||
      (!_missingTitle(local) &&
          local.author.isNotEmpty &&
          local.thumbnailUrl.isNotEmpty)) {
    return local;
  }
  try {
    final video = await sharedYoutubeExplode.videos
        .get(local.videoId)
        .timeout(const Duration(seconds: 5));
    return _merge(
      local,
      video.title,
      video.author,
      video.thumbnails.highResUrl,
    );
  } catch (_) {
    return local;
  }
}
