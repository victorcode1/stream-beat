import 'dart:convert';

import 'package:flow_music/features/radio/data/custom_station.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/data/repositories/radio_browser_repository.dart';
import 'package:flow_music/features/radio/data/station_removals_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const blockedUuid = '00000000-0000-4000-8000-000000000001';
StationRemovalsRepository removals() => StationRemovalsRepository(
  client: MockClient(
    (_) async => http.Response(
      jsonEncode({
        'version': 1,
        'updatedAt': '2026-10-15T00:00:00Z',
        'stationUuids': [blockedUuid],
        'streamHosts': ['blocked.test'],
      }),
      200,
    ),
  ),
  readCache: () => null,
  writeCache: (_) async {},
  loadAsset: () async =>
      '{"version":1,"updatedAt":"1970-01-01T00:00:00Z","stationUuids":[],"streamHosts":[]}',
);

void main() {
  test('filters search, home/map results and shared station lookups', () async {
    final repository = RadioBrowserRepository(
      removalsRepository: removals(),
      client: MockClient((request) async {
        if (request.url.host == 'all.api.radio-browser.info') {
          return http.Response('[]', 200);
        }
        return http.Response(
          jsonEncode([
            {'stationuuid': blockedUuid, 'url': 'https://allowed.test/live'},
            {'stationuuid': 'blocked-host', 'url': 'https://blocked.test/live'},
            {
              'stationuuid': 'blocked-original',
              'url': 'http://blocked.test/original',
              'url_resolved': 'https://allowed.test/live',
            },
            {'stationuuid': 'allowed', 'url': 'https://allowed.test/live'},
          ]),
          200,
        );
      }),
    );
    expect(
      (await repository.searchStations(
        name: 'Radio',
      )).map((station) => station.stationUuid),
      ['allowed'],
    );
    expect(
      (await repository.topStations()).map((station) => station.stationUuid),
      ['allowed'],
    );
    // A real byuuid response contains only the requested station.
    final sharedRepository = RadioBrowserRepository(
      removalsRepository: removals(),
      client: MockClient((request) async {
        if (request.url.host == 'all.api.radio-browser.info') {
          return http.Response('[]', 200);
        }
        return http.Response(
          jsonEncode([
            {'stationuuid': blockedUuid, 'url': 'https://allowed.test/live'},
          ]),
          200,
        );
      }),
    );
    expect(await sharedRepository.stationByUuid(blockedUuid), isNull);
  });

  test(
    'blocks withdrawn stations before click resolution and retries',
    () async {
      var calls = 0;
      final repository = RadioBrowserRepository(
        removalsRepository: removals(),
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      final station = RadioStation.fromJson({
        'stationuuid': blockedUuid,
        'url': 'https://allowed.test/live',
      });
      await expectLater(
        repository.countClickAndResolveUrl(station),
        throwsA(isA<StationUnavailableException>()),
      );
      await expectLater(
        repository.refreshResolvedUrl(station),
        throwsA(isA<StationUnavailableException>()),
      );
      expect(calls, 0);
    },
  );

  test('checks newly resolved stream hosts too', () async {
    final repository = RadioBrowserRepository(
      removalsRepository: removals(),
      client: MockClient((request) async {
        if (request.url.host == 'all.api.radio-browser.info') {
          return http.Response('[]', 200);
        }
        if (request.url.path.startsWith('/json/url/')) {
          return http.Response('{"url":"https://blocked.test/new"}', 200);
        }
        return http.Response(
          '[{"stationuuid":"allowed","url":"https://blocked.test/new"}]',
          200,
        );
      }),
    );
    final station = RadioStation.fromJson({
      'stationuuid': 'allowed',
      'url': 'https://allowed.test/live',
    });
    await expectLater(
      repository.countClickAndResolveUrl(station),
      throwsA(isA<StationUnavailableException>()),
    );
    await expectLater(
      repository.refreshResolvedUrl(station),
      throwsA(isA<StationUnavailableException>()),
    );
  });

  test(
    'custom station bypasses removals, clicks, retry lookup, and health writes',
    () async {
      var calls = 0;
      final repository = RadioBrowserRepository(
        removalsRepository: removals(),
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      final station = createCustomStation(
        name: 'Own radio',
        streamUrl: 'https://blocked.test/live',
      );
      expect(
        await repository.countClickAndResolveUrl(station),
        station.streamUrl,
      );
      expect(await repository.refreshResolvedUrl(station), station.streamUrl);
      await repository.healthRepository.recordFailure(station);
      await repository.healthRepository.recordSuccess(station);
      expect(repository.healthRepository.read(station).consecutiveFailures, 0);
      expect(calls, 0);
    },
  );
}
