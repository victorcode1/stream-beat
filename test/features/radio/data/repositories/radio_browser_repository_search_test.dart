import 'package:flow_music/features/radio/data/station_removals_repository.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/data/repositories/radio_browser_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('search sends station name and country code together', () async {
    Uri? searchUri;
    final client = MockClient((request) async {
      if (request.url.host == 'all.api.radio-browser.info') {
        return http.Response('[{"name":"radio.example.test"}]', 200);
      }

      searchUri = request.url;
      return http.Response('[]', 200);
    });
    final repository = RadioBrowserRepository(
      client: client,
      removalsRepository: _emptyRemovals(),
    );

    await repository.searchStations(name: 'Rock FM', countryCode: 'pa');

    expect(searchUri?.path, '/json/stations/search');
    expect(searchUri?.queryParameters['name'], 'Rock FM');
    expect(searchUri?.queryParameters['countrycode'], 'PA');
  });

  test('uses an exact country name as the country filter', () async {
    Uri? searchUri;
    final client = MockClient((request) async {
      if (request.url.host == 'all.api.radio-browser.info') {
        return http.Response('[{"name":"radio.example.test"}]', 200);
      }

      searchUri = request.url;
      return http.Response(
        '[{"stationuuid":"panama","name":"Beat Life Panama",'
        '"countrycode":"PA",'
        '"url_resolved":"https://radio.example/panama"}]',
        200,
      );
    });
    final repository = RadioBrowserRepository(
      client: client,
      removalsRepository: _emptyRemovals(),
    );

    final stations = await repository.searchStations(name: 'PÁNAMÁ');

    expect(searchUri?.queryParameters.containsKey('name'), isFalse);
    expect(searchUri?.queryParameters['countrycode'], 'PA');
    expect(stations.map((station) => station.stationUuid), ['panama']);
  });

  test('does not treat a partial country name as a country filter', () async {
    Uri? searchUri;
    final client = MockClient((request) async {
      if (request.url.host == 'all.api.radio-browser.info') {
        return http.Response('[{"name":"radio.example.test"}]', 200);
      }

      searchUri = request.url;
      return http.Response('[]', 200);
    });
    final repository = RadioBrowserRepository(
      client: client,
      removalsRepository: _emptyRemovals(),
    );

    await repository.searchStations(name: 'pana');

    expect(searchUri?.queryParameters['name'], 'pana');
    expect(searchUri?.queryParameters.containsKey('countrycode'), isFalse);
  });

  test('shares server discovery between simultaneous requests', () async {
    var discoveryCalls = 0;
    final client = MockClient((request) async {
      if (request.url.host == 'all.api.radio-browser.info') {
        discoveryCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 1));
        return http.Response('[{"name":"radio.example.test"}]', 200);
      }

      return http.Response('[]', 200);
    });
    final repository = RadioBrowserRepository(
      client: client,
      removalsRepository: _emptyRemovals(),
    );

    await Future.wait([repository.topStations(), repository.topTags()]);

    expect(discoveryCalls, 1);
  });

  test('retries another discovered server after a server error', () async {
    final requestedHosts = <String>[];
    final client = MockClient((request) async {
      if (request.url.host == 'all.api.radio-browser.info') {
        return http.Response(
          '[{"name":"broken.radio.test"},'
          '{"name":"healthy.radio.test"}]',
          200,
        );
      }

      requestedHosts.add(request.url.host);
      if (request.url.host == 'broken.radio.test') {
        return http.Response('temporarily unavailable', 503);
      }
      return http.Response('[]', 200);
    });
    final repository = RadioBrowserRepository(
      client: client,
      removalsRepository: _emptyRemovals(),
    );

    await repository.topStations();

    expect(requestedHosts, ['broken.radio.test', 'healthy.radio.test']);
  });

  test('requests and retains only HTTPS stations when required', () async {
    Uri? stationUri;
    final client = MockClient((request) async {
      if (request.url.host == 'all.api.radio-browser.info') {
        return http.Response('[{"name":"radio.example.test"}]', 200);
      }

      stationUri = request.url;
      return http.Response(
        '[{"stationuuid":"http","name":"HTTP",'
        '"url_resolved":"http://stream.example/http"},'
        '{"stationuuid":"https","name":"HTTPS",'
        '"url_resolved":"https://stream.example/https"}]',
        200,
      );
    });
    final repository = RadioBrowserRepository(
      client: client,
      removalsRepository: _emptyRemovals(),
      requireHttps: true,
    );

    final stations = await repository.searchStations(name: 'Radio');

    expect(stationUri?.queryParameters['is_https'], 'true');
    expect(stations.map((station) => station.stationUuid), ['https']);
  });

  test('refreshes the resolved URL by station UUID before retrying', () async {
    Uri? refreshUri;
    final client = MockClient((request) async {
      if (request.url.host == 'all.api.radio-browser.info') {
        return http.Response('[{"name":"radio.example.test"}]', 200);
      }

      refreshUri = request.url;
      return http.Response(
        '[{"stationuuid":"station-1","name":"Radio",'
        '"url_resolved":"https://new.example/live"}]',
        200,
      );
    });
    final repository = RadioBrowserRepository(
      client: client,
      removalsRepository: _emptyRemovals(),
    );
    final station = RadioStation.fromJson(const {
      'stationuuid': 'station-1',
      'name': 'Radio',
      'url_resolved': 'https://old.example/live',
    });

    final refreshed = await repository.refreshResolvedUrl(
      station,
      fallbackUrl: 'https://first-attempt.example/live',
    );

    expect(refreshUri?.path, '/json/stations/byuuid');
    expect(refreshUri?.queryParameters['uuids'], 'station-1');
    expect(refreshed, 'https://new.example/live');
  });

  test('does not fall back to HTTP when HTTPS is required', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'all.api.radio-browser.info') {
        return http.Response('[{"name":"radio.example.test"}]', 200);
      }
      return http.Response('service unavailable', 503);
    });
    final repository = RadioBrowserRepository(
      client: client,
      removalsRepository: _emptyRemovals(),
      requireHttps: true,
    );
    final station = RadioStation.fromJson(const {
      'stationuuid': 'station-1',
      'name': 'HTTP only',
      'url_resolved': 'http://radio.example/live',
    });

    expect(
      () => repository.countClickAndResolveUrl(station),
      throwsA(isA<RadioBrowserException>()),
    );
  });

  test('also searches a normalized accent and punctuation variant', () async {
    final searchedNames = <String>[];
    final client = MockClient((request) async {
      if (request.url.host == 'all.api.radio-browser.info') {
        return http.Response('[{"name":"radio.example.test"}]', 200);
      }

      final name = request.url.queryParameters['name'] ?? '';
      searchedNames.add(name);
      if (name == 'maxima fm') {
        return http.Response(
          '[{"stationuuid":"maxima","name":"Máxima FM",'
          '"url_resolved":"https://radio.example/maxima"}]',
          200,
        );
      }
      return http.Response('[]', 200);
    });
    final repository = RadioBrowserRepository(
      client: client,
      removalsRepository: _emptyRemovals(),
    );

    final stations = await repository.searchStations(name: 'MÁXIMA-FM');

    expect(searchedNames, containsAll(['MÁXIMA-FM', 'maxima fm']));
    expect(stations.map((station) => station.stationUuid), ['maxima']);
  });
}

StationRemovalsRepository _emptyRemovals() => StationRemovalsRepository(
  client: MockClient((_) async => http.Response('', 404)),
  readCache: () => null,
  writeCache: (_) async {},
  loadAsset: () async =>
      '{"version":1,"updatedAt":"1970-01-01T00:00:00Z","stationUuids":[],"streamHosts":[]}',
);
