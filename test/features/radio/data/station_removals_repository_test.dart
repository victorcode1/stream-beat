import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/data/station_removals_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> manifest({
  List<String> ids = const [],
  List<String> hosts = const [],
}) => {
  'version': 1,
  'updatedAt': '2026-10-15T12:00:00Z',
  'stationUuids': ids,
  'streamHosts': hosts,
};
RadioStation station(
  String id, {
  String url = 'https://stream.example/live',
  String resolved = '',
}) => RadioStation.fromJson({
  'stationuuid': id,
  'url': url,
  'url_resolved': resolved,
});

void main() {
  test('bundled manifest is valid and starts with empty lists', () {
    final source =
        jsonDecode(File('assets/station_removals.json').readAsStringSync())
            as Map<String, dynamic>;
    final removals = StationRemovals.fromJson(source);
    expect(removals.stationUuids, isEmpty);
    expect(removals.streamHosts, isEmpty);
  });

  test(
    'parses normalized UUIDs and matches original or resolved exact host',
    () {
      final removals = StationRemovals.fromJson(
        manifest(ids: [' ID-1 '], hosts: [' STREAM.EXAMPLE ']),
      );
      expect(
        removals.contains(station('id-1', url: 'https://other.test')),
        isTrue,
      );
      expect(removals.contains(station('other')), isTrue);
      expect(
        removals.contains(
          station(
            'other',
            url: 'https://other.test',
            resolved: 'https://stream.example/live',
          ),
        ),
        isTrue,
      );
      expect(
        removals.contains(
          station('other', url: 'https://stream.example.evil.test'),
        ),
        isFalse,
      );
      expect(removals.contains(station('custom-own')), isFalse);
    },
  );

  test('rejects malformed and unsupported manifests', () {
    for (final value in [
      <String, dynamic>{},
      {...manifest(), 'version': 2},
      {...manifest(), 'updatedAt': 'invalid'},
      {
        ...manifest(),
        'stationUuids': [1],
      },
      {...manifest(), 'streamHosts': null},
    ]) {
      expect(() => StationRemovals.fromJson(value), throwsFormatException);
    }
  });

  test(
    'caches remote response, coalesces requests, and waits six hours',
    () async {
      var now = DateTime.utc(2026, 10, 15);
      var calls = 0;
      String? cache;
      final repository = StationRemovalsRepository(
        client: MockClient((_) async {
          calls++;
          return http.Response(jsonEncode(manifest(ids: ['blocked'])), 200);
        }),
        readCache: () => cache,
        writeCache: (value) async => cache = value,
        loadAsset: () async => jsonEncode(manifest()),
        now: () => now,
      );
      await Future.wait([repository.load(), repository.load()]);
      expect(calls, 1);
      expect(repository.current.contains(station('blocked')), isTrue);
      expect(jsonDecode(cache!)['data']['stationUuids'], ['blocked']);
      now = now.add(const Duration(hours: 5, minutes: 59));
      await repository.load();
      expect(calls, 1);
      now = now.add(const Duration(minutes: 1));
      await repository.load();
      expect(calls, 2);
    },
  );

  test(
    'uses fresh persisted cache across repository instances without network',
    () async {
      final now = DateTime.utc(2026, 10, 15);
      final repository = StationRemovalsRepository(
        client: MockClient((_) async => throw StateError('must not request')),
        readCache: () => jsonEncode({
          'checkedAt': now.toIso8601String(),
          'data': manifest(ids: ['blocked']),
        }),
        loadAsset: () async => throw StateError('must not load asset'),
        now: () => now,
      );
      expect((await repository.load()).contains(station('blocked')), isTrue);
    },
  );

  for (final status in [500, 200]) {
    test('keeps stale cache on HTTP $status with invalid response', () async {
      final repository = StationRemovalsRepository(
        client: MockClient((_) async => http.Response('not json', status)),
        readCache: () => jsonEncode({
          'checkedAt': '2020-01-01T00:00:00Z',
          'data': manifest(ids: ['blocked']),
        }),
        writeCache: (_) async {},
        loadAsset: () async => jsonEncode(manifest()),
      );
      expect((await repository.load()).contains(station('blocked')), isTrue);
    });
  }

  test(
    'uses asset after a corrupt cache and offline failure; throttles failures',
    () async {
      var calls = 0;
      final repository = StationRemovalsRepository(
        client: MockClient((_) async {
          calls++;
          throw http.ClientException('offline');
        }),
        readCache: () => 'broken',
        writeCache: (_) async {},
        loadAsset: () async => jsonEncode(manifest(hosts: ['stream.example'])),
      );
      expect((await repository.load()).contains(station('id')), isTrue);
      await repository.load();
      expect(calls, 1);
    },
  );

  test('returns bundled fallback promptly on timeout', () async {
    final repository = StationRemovalsRepository(
      client: MockClient((_) => Completer<http.Response>().future),
      timeout: const Duration(milliseconds: 1),
      readCache: () => null,
      writeCache: (_) async {},
      loadAsset: () async => jsonEncode(manifest()),
    );
    expect((await repository.load()).stationUuids, isEmpty);
  });

  test('404 replaces previous cache with an empty manifest', () async {
    String? saved;
    final repository = StationRemovalsRepository(
      client: MockClient((_) async => http.Response('', 404)),
      readCache: () => jsonEncode({
        'checkedAt': '2020-01-01T00:00:00Z',
        'data': manifest(ids: ['blocked']),
      }),
      writeCache: (value) async => saved = value,
    );
    expect((await repository.load()).contains(station('blocked')), isFalse);
    expect(jsonDecode(saved!)['data']['stationUuids'], isEmpty);
  });
}
