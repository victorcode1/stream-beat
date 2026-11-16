import 'dart:async';

import 'package:flow_music/core/audio/background_audio_handler.dart';
import 'package:flow_music/features/autoplay/data/resolved_audio.dart';
import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/features/song/presentation/controllers/song_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _StoppingHandler implements FlowAudioHandler {
  void Function()? onStop;

  @override
  Future<void> stop() async => onStop?.call();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('streambeat/background_task');
  final handler = _StoppingHandler();
  final calls = <String>[];
  setUpAll(() => flowAudioHandler = handler);

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return null;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    handler.onStop = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'only the latest selection starts after native protection is ready',
    () async {
      final beginRequested = Completer<void>();
      final beginGate = Completer<void>();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(songController);
      final stoppedIds = <String?>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            if (call.method == 'begin') {
              beginRequested.complete();
              await beginGate.future;
            }
            return null;
          });
      handler.onStop = () {
        stoppedIds.add(controller.currentVideoId);
        controller.preloadMetadata(videoId: 'cancelled');
      };

      final old = controller.playAudio(id: 'old');
      await beginRequested.future;
      final latest = controller.playAudio(id: 'latest');
      beginGate.complete();
      await Future.wait([old, latest]);

      expect(stoppedIds, ['latest']);
      expect(calls, ['begin', 'end']);
    },
  );

  for (final prefetched in [false, true]) {
    test(
      '${prefetched ? 'prefetched' : 'selected'} song protects preparation before stopping audio',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(songController);
        late List<String> protectionAtStop;
        handler.onStop = () {
          protectionAtStop = [...calls];
          // Cancel at the first asynchronous boundary, before disk/network IO.
          controller.preloadMetadata(videoId: 'newer-selection');
        };

        if (prefetched) {
          await controller.playPrefetched(
            const ResolvedAudio(
              suggestion: YouTubeSearchSuggestion(
                videoId: 'selected',
                displayText: 'Selected',
                channelTitle: 'Artist',
                thumbnailUrl: '',
              ),
              audioUrl: 'https://example.com/selected.m4a',
            ),
          );
        } else {
          await controller.playAudio(id: 'selected');
        }

        expect(protectionAtStop, ['begin']);
        expect(calls, ['begin', 'end']);
        expect(controller.currentVideoId, 'newer-selection');
      },
    );
  }
}
