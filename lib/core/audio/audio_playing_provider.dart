import 'package:flow_music/core/audio/background_audio_handler.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Whether the radio is currently playing (or buffering to play).
final audioPlayingProvider = StreamProvider<bool>((ref) {
  return flowAudioHandler.playbackState
      .map((state) => state.playing)
      .distinct();
});
