import 'package:audio_service/audio_service.dart';
import 'package:flow_music/core/audio/background_audio_handler.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Whether the radio is playing or about to (loading/buffering).
///
/// audio_service keeps `playing` true after a failed stream, so error and
/// idle states count as silent.
final audioPlayingProvider = StreamProvider<bool>((ref) {
  return flowAudioHandler.playbackState.map(isAudiblePlayback).distinct();
});

bool isAudiblePlayback(PlaybackState state) =>
    state.playing &&
    state.processingState != AudioProcessingState.error &&
    state.processingState != AudioProcessingState.idle;
