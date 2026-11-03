import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const _anonymousIdKey = 'product_analytics_anonymous_id';

final productAnalyticsProvider = Provider<ProductAnalytics>(
  (ref) => ProductAnalytics.noop(),
);

abstract interface class AnalyticsEventSink {
  Future<void> write(Map<String, dynamic> event);
}

class ProductAnalytics {
  ProductAnalytics({
    required AnalyticsEventSink sink,
    required this.anonymousId,
    required this.sessionId,
    required this.platform,
    required this.appVersion,
    required String Function() localeProvider,
  }) : _sink = sink,
       _localeProvider = localeProvider;

  factory ProductAnalytics.create({
    required Box<dynamic> settingsBox,
    required String version,
    required String buildNumber,
  }) {
    final storedId = settingsBox.get(_anonymousIdKey);
    final anonymousId = storedId is String && _isUuid(storedId)
        ? storedId
        : generateAnalyticsUuid();
    if (storedId != anonymousId) {
      settingsBox.put(_anonymousIdKey, anonymousId);
    }

    return ProductAnalytics(
      sink: const _NoopAnalyticsEventSink(),
      anonymousId: anonymousId,
      sessionId: generateAnalyticsUuid(),
      platform: _currentPlatform(),
      appVersion: '$version+$buildNumber',
      localeProvider: () => PlatformDispatcher.instance.locale.toLanguageTag(),
    );
  }

  factory ProductAnalytics.noop() {
    return ProductAnalytics(
      sink: const _NoopAnalyticsEventSink(),
      anonymousId: '00000000-0000-4000-8000-000000000000',
      sessionId: '00000000-0000-4000-8000-000000000000',
      platform: 'other',
      appVersion: '0.0.0+0',
      localeProvider: () => 'und',
    );
  }

  final AnalyticsEventSink _sink;
  final String Function() _localeProvider;
  final String anonymousId;
  final String sessionId;
  final String platform;
  final String appVersion;

  Future<void> track(
    String eventName, {
    Map<String, Object?> properties = const {},
  }) async {
    assert(
      RegExp(r'^[a-z][a-z0-9_]{1,63}$').hasMatch(eventName),
      'Invalid analytics event name: $eventName',
    );

    try {
      await _sink.write({
        'event_name': eventName,
        'anonymous_id': anonymousId,
        'session_id': sessionId,
        'platform': platform,
        'app_version': appVersion,
        'locale': _localeProvider(),
        'properties': properties,
      });
    } catch (error) {
      // Product measurement must never interrupt playback or navigation.
      debugPrint('Unable to record product analytics event: $error');
    }
  }
}

class _NoopAnalyticsEventSink implements AnalyticsEventSink {
  const _NoopAnalyticsEventSink();

  @override
  Future<void> write(Map<String, dynamic> event) async {}
}

String generateAnalyticsUuid([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => source.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

bool _isUuid(String value) {
  return RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(value);
}

String _currentPlatform() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'other',
  };
}
