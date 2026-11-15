import 'dart:async';
import 'package:flow_music/core/audio/background_audio_handler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;

class TestPlayer extends ja.AudioPlayer {
  double testVolume = 1;
  Completer<void>? volumeGate;
  final loaded = <String>[];
  final positions = StreamController<Duration>.broadcast();

  @override
  Duration? get duration => const Duration(seconds: 10);
  @override
  Stream<Duration> createPositionStream({
    int steps = 800,
    Duration minPeriod = const Duration(milliseconds: 200),
    Duration maxPeriod = const Duration(milliseconds: 200),
  }) => positions.stream;
  @override
  Future<Duration?> setAudioSources(
    List<ja.AudioSource> sources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    ja.ShuffleOrder? shuffleOrder,
  }) async {
    loaded.add((sources.single as ja.IndexedAudioSource).tag.id as String);
    return duration;
  }

  @override
  Future<void> addAudioSource(ja.AudioSource source) async {}
  @override
  Future<void> play() async {}

  @override
  Future<void> setVolume(double volume) async {
    final gate = volumeGate;
    volumeGate = null;
    if (gate != null) await gate.future;
    testVolume = volume;
  }

  @override
  double get volume => testVolume;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'an old load cannot replace the last selection after delayed volume setup',
    () async {
      final player = TestPlayer();
      final handler = FlowAudioHandler(audioPlayer: player);
      handler.setSmoothTransitions(false);
      await Future<void>.delayed(Duration.zero);
      final gate = Completer<void>();
      player.volumeGate = gate;
      final old = handler.playUrl(
        url: 'https://example.com/a.mp3',
        id: 'old',
        title: 'Old',
        artist: 'Artist',
      );
      await Future<void>.delayed(Duration.zero);
      await handler.playUrl(
        url: 'https://example.com/b.mp3',
        id: 'latest',
        title: 'Latest',
        artist: 'Artist',
      );
      gate.complete();
      await old;
      expect(player.loaded, ['latest']);
      expect(handler.mediaItem.value?.id, 'latest');
      await handler.dispose();
      await player.positions.close();
    },
  );

  test(
    'late native preparation cancels an active fade in another section',
    () async {
      final player = TestPlayer();
      final handler = FlowAudioHandler(audioPlayer: player);
      final next = Completer<QueuedTrack?>();
      handler.prepareNextTrack = (_) => next.future;
      await handler.playUrl(
        url: 'https://example.com/a.mp3',
        id: 'a',
        title: 'A',
        artist: 'Artist',
        canonicalDuration: const Duration(seconds: 10),
      );
      await Future<void>.delayed(const Duration(milliseconds: 800));
      player.positions.add(const Duration(seconds: 9));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(player.volume, lessThan(1));
      next.complete(
        const QueuedTrack(
          id: 'b',
          title: 'B',
          artist: 'Artist',
          url: 'https://example.com/b.mp3',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(player.volume, 1);
      await handler.dispose();
      await player.positions.close();
    },
  );

  test('background entry cancels a fade and restores audible volume', () async {
    final player = TestPlayer();
    final handler = FlowAudioHandler(audioPlayer: player);
    await player.setVolume(0);
    await handler.setAppInBackground(true);
    expect(player.volume, 1);
    handler.setSmoothTransitions(true);
    await Future<void>.delayed(Duration.zero);
    expect(player.volume, 1);
    await handler.setAppInBackground(false);
    expect(player.volume, 1);
    await handler.dispose();
    await player.positions.close();
  });
}
