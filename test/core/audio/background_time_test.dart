import 'dart:async';

import 'package:flow_music/core/audio/background_time.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('streambeat/background_task');
  final calls = <String>[];

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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'overlapping loads keep protection until the last load finishes',
    () async {
      final firstGate = Completer<void>();
      final secondGate = Completer<void>();
      final firstStarted = Completer<void>();
      final secondStarted = Completer<void>();
      final first = withBackgroundTime(() {
        firstStarted.complete();
        return firstGate.future;
      });
      await firstStarted.future;
      final second = withBackgroundTime(() {
        secondStarted.complete();
        return secondGate.future;
      });
      await secondStarted.future;
      firstGate.complete();
      await first;
      final callsWhileLoading = [...calls];
      secondGate.complete();
      await second;

      expect(callsWhileLoading, ['begin']);
      expect(calls, ['begin', 'end']);
    },
  );

  test('nested fallback does not end the outer background task', () async {
    late List<String> afterFallback;
    final result = await withBackgroundTime(() async {
      await withBackgroundTime(() async => 'fallback');
      afterFallback = [...calls];
      return 'playing';
    });

    expect(afterFallback, ['begin']);
    expect(calls, ['begin', 'end']);
    expect(result, 'playing');
  });

  test('overlapping operations wait for native protection to begin', () async {
    final beginRequested = Completer<void>();
    final beginGate = Completer<void>();
    var started = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'begin') {
            beginRequested.complete();
            await beginGate.future;
          }
          return null;
        });

    final first = withBackgroundTime(() async => started++);
    await beginRequested.future;
    final second = withBackgroundTime(() async => started++);
    expect(started, 0);
    beginGate.complete();
    await Future.wait([first, second]);
    expect(started, 2);
    expect(calls, ['begin', 'end']);
  });

  test(
    'failed preparation releases protection and preserves the error',
    () async {
      final error = StateError('source failed');
      await expectLater(
        withBackgroundTime<void>(() async => throw error),
        throwsA(same(error)),
      );
      expect(calls, ['begin', 'end']);
    },
  );

  test('Android runs the operation without the iOS channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(await withBackgroundTime(() async => 42), 42);
    expect(calls, isEmpty);
  });
}
