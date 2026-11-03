import 'package:audio_service/audio_service.dart';
import 'package:flow_music/core/audio/audio_playing_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PlaybackState state(bool playing, AudioProcessingState processing) =>
      PlaybackState(playing: playing, processingState: processing);

  test('only counts audible or starting playback as playing', () {
    expect(isAudiblePlayback(state(true, AudioProcessingState.ready)), isTrue);
    expect(
      isAudiblePlayback(state(true, AudioProcessingState.buffering)),
      isTrue,
    );
    expect(isAudiblePlayback(state(true, AudioProcessingState.error)), isFalse);
    expect(isAudiblePlayback(state(true, AudioProcessingState.idle)), isFalse);
    expect(
      isAudiblePlayback(state(false, AudioProcessingState.ready)),
      isFalse,
    );
  });
}
