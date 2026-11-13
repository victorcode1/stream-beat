import 'package:audio_service/audio_service.dart';
import 'package:flow_music/core/audio/background_audio_handler.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Streams the title of the currently-playing media (song, video, radio).
/// Returns `null` when nothing meaningful is loaded so callers can fall back
/// to a default label.
final nowPlayingTitleProvider = StreamProvider<String?>((ref) {
  return flowAudioHandler.mediaItem.map(_titleFromItem);
});

String? _titleFromItem(MediaItem? item) {
  final title = item?.title.trim();
  if (title == null || title.isEmpty) return null;
  // The handler uses "StreamBeat" as a placeholder when the source has no
  // title — treat that as no real track playing.
  if (title == 'StreamBeat') return null;
  return title;
}

/// Id de lo que esta cargado en el reproductor (el videoId en canciones), para
/// que las listas marquen la cancion activa.
final nowPlayingIdProvider = StreamProvider<String?>((ref) {
  return flowAudioHandler.mediaItem.map((item) => item?.id).distinct();
});

/// El reproductor esta sonando (no en pausa ni detenido).
final nowPlayingIsPlayingProvider = StreamProvider<bool>((ref) {
  return flowAudioHandler.playbackState
      .map((state) => state.playing)
      .distinct();
});
