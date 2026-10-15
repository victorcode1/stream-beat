import 'dart:async';
import 'dart:convert';

import 'package:flow_music/core/utils/search_text_normalizer.dart';
import 'package:flow_music/features/radio/data/models/radio_country.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/data/models/radio_tag.dart';
import 'package:flow_music/features/radio/data/radio_station_health_repository.dart';
import 'package:flow_music/features/radio/data/station_removals_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class RadioBrowserRepository {
  RadioBrowserRepository({
    http.Client? client,
    StationRemovalsRepository? removalsRepository,
    Duration requestTimeout = const Duration(seconds: 10),
    bool? requireHttps,
    RadioStationHealthRepository? healthRepository,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       removalsRepository =
           removalsRepository ?? StationRemovalsRepository.instance,
       _requestTimeout = requestTimeout,
       _requireHttps = requireHttps ?? kIsWeb,
       healthRepository = healthRepository ?? RadioStationHealthRepository();

  static const _serverDiscoveryUrl =
      'https://all.api.radio-browser.info/json/servers';
  static const _fallbackBaseUrl = 'https://de1.api.radio-browser.info';
  static const _maximumServersPerRequest = 3;

  final StationRemovalsRepository removalsRepository;
  final http.Client _client;
  final bool _ownsClient;
  final Duration _requestTimeout;
  final bool _requireHttps;
  final RadioStationHealthRepository healthRepository;
  List<String>? _baseUrls;
  Future<List<String>>? _baseUrlsFuture;
  String? _preferredBaseUrl;

  Future<List<RadioStation>> topStations({int limit = 30}) async {
    return _getStations('/json/stations/topclick/$limit', {
      'hidebroken': 'true',
      if (_requireHttps) 'is_https': 'true',
      'order': 'clickcount',
      'reverse': 'true',
    });
  }

  Future<RadioStation?> stationByUuid(String rawUuid) async {
    final uuid = rawUuid.trim();
    if (!isRadioStationUuid(uuid)) return null;
    final stations = await _getStations('/json/stations/byuuid', {
      'uuids': uuid,
      'hidebroken': 'true',
      if (_requireHttps) 'is_https': 'true',
    });
    return stations.isEmpty ? null : stations.first;
  }

  Future<List<RadioStation>> searchStations({
    String name = '',
    String tag = '',
    String countryCode = '',
    int limit = 30,
  }) async {
    final rawName = name.trim();
    final requestedCountryCode = countryCode.trim().toUpperCase();
    final matchedCountry = requestedCountryCode.isEmpty
        ? findRadioCountryExact(rawName)
        : null;
    final effectiveCountryCode = requestedCountryCode.isNotEmpty
        ? requestedCountryCode
        : matchedCountry?.code ?? '';
    final effectiveName = matchedCountry == null ? rawName : '';
    final normalizedName = normalizeSearchQuery(effectiveName);
    final queryNames = <String>{
      effectiveName,
      if (normalizedName.isNotEmpty &&
          normalizedName != effectiveName.toLowerCase())
        normalizedName,
    };

    final results = await Future.wait(
      queryNames.map(
        (queryName) => _getStations('/json/stations/search', {
          if (queryName.isNotEmpty) 'name': queryName,
          if (tag.trim().isNotEmpty) 'tag': tag.trim(),
          if (effectiveCountryCode.isNotEmpty)
            'countrycode': effectiveCountryCode,
          'hidebroken': 'true',
          if (_requireHttps) 'is_https': 'true',
          'order': 'clickcount',
          'reverse': 'true',
          'limit': '$limit',
        }),
      ),
    );

    final merged = <String, RadioStation>{};
    for (final station in results.expand((stations) => stations)) {
      final key = station.stationUuid.isNotEmpty
          ? station.stationUuid
          : station.streamUrl;
      merged[key] = station;
    }
    return healthRepository.rank(merged.values);
  }

  Future<List<RadioTag>> topTags({int limit = 16}) async {
    final data = await _getList('/json/tags', {
      'order': 'stationcount',
      'reverse': 'true',
      'limit': '$limit',
    });
    return data
        .map(RadioTag.fromJson)
        .where((tag) => tag.name.isNotEmpty)
        .toList();
  }

  Future<String> countClickAndResolveUrl(RadioStation station) async {
    await _checkAvailable(station);
    final fallback = _canUseStreamUrl(station.streamUrl)
        ? station.streamUrl
        : null;
    if (station.isCustomStation || station.stationUuid.isEmpty) {
      return fallback ?? _throwIncompatibleStream();
    }

    try {
      final response = await _get('/json/url/${station.stationUuid}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return fallback ?? _throwIncompatibleStream();
      }

      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final resolvedUrl = data['url'] as String? ?? '';
        _checkResolvedUrl(station, resolvedUrl);
        return _canUseStreamUrl(resolvedUrl)
            ? resolvedUrl.trim()
            : fallback ?? _throwIncompatibleStream();
      }
    } on StationUnavailableException {
      rethrow;
    } catch (_) {
      return fallback ?? _throwIncompatibleStream();
    }

    return fallback ?? _throwIncompatibleStream();
  }

  /// Fetches the latest station record without incrementing its click count.
  /// Used before the automatic retry so a changed redirect/playlist is not
  /// retried with the same stale resolved URL.
  Future<String> refreshResolvedUrl(
    RadioStation station, {
    String? fallbackUrl,
  }) async {
    await _checkAvailable(station);
    if (fallbackUrl != null) _checkResolvedUrl(station, fallbackUrl);
    final fallback = _canUseStreamUrl(fallbackUrl ?? '')
        ? fallbackUrl!.trim()
        : _canUseStreamUrl(station.streamUrl)
        ? station.streamUrl
        : null;
    if (station.isCustomStation || station.stationUuid.isEmpty) {
      return fallback ?? _throwIncompatibleStream();
    }

    try {
      final data = await _getList('/json/stations/byuuid', {
        'uuids': station.stationUuid,
      });
      for (final item in data) {
        final refreshed = RadioStation.fromJson(item);
        if (removalsRepository.current.contains(refreshed)) {
          throw const StationUnavailableException();
        }
        if (refreshed.isPlayable && (!_requireHttps || refreshed.isHttps)) {
          return refreshed.streamUrl;
        }
      }
    } on StationUnavailableException {
      rethrow;
    } catch (_) {
      // The initial resolved URL remains the safest fallback.
    }
    return fallback ?? _throwIncompatibleStream();
  }

  Future<String?> resolveArtworkUrl(RadioStation station) async {
    final artworkUrl = station.artworkUrl;
    if (artworkUrl.isEmpty) return null;

    try {
      final uri = Uri.parse(artworkUrl);
      final response = await _client
          .head(uri, headers: _imageHeaders)
          .timeout(_requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return artworkUrl;
      }

      // Algunos servidores no permiten HEAD aunque la imagen sí se pueda
      // descargar. En esos casos confirmamos con GET antes de conservar la URL.
      if (response.statusCode == 403 || response.statusCode == 405) {
        final getResponse = await _client
            .get(uri, headers: {..._imageHeaders, 'Range': 'bytes=0-0'})
            .timeout(_requestTimeout);
        if (getResponse.statusCode >= 200 && getResponse.statusCode < 300) {
          return artworkUrl;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  Future<List<RadioStation>> _getStations(
    String path, [
    Map<String, String>? queryParameters,
  ]) async {
    await removalsRepository.load();
    final data = await _getList(path, queryParameters);
    final stations = data
        .map(RadioStation.fromJson)
        .where((station) => !removalsRepository.current.contains(station))
        .where((station) => station.isPlayable)
        .where((station) => !_requireHttps || station.isHttps)
        .toList();
    return healthRepository.rank(stations);
  }

  Future<List<Map<String, dynamic>>> _getList(
    String path, [
    Map<String, String>? queryParameters,
  ]) async {
    final response = await _get(path, queryParameters);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RadioBrowserException(
        'Radio Browser request failed with ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);
    if (data is! List) {
      throw const RadioBrowserException('Radio Browser returned invalid data');
    }

    return data.whereType<Map<String, dynamic>>().toList();
  }

  Future<http.Response> _get(
    String path, [
    Map<String, String>? queryParameters,
  ]) async {
    final servers = await _resolveBaseUrls();
    final preferred = _preferredBaseUrl;
    final orderedServers = <String>{
      ?preferred,
      ...servers,
    }.take(_maximumServersPerRequest);
    http.Response? lastResponse;
    Object? lastError;

    for (final baseUrl in orderedServers) {
      final uri = Uri.parse(
        '$baseUrl$path',
      ).replace(queryParameters: queryParameters);
      try {
        final response = await _client
            .get(uri, headers: _headers)
            .timeout(_requestTimeout);
        lastResponse = response;

        if (response.statusCode < 500 && response.statusCode != 429) {
          _preferredBaseUrl = baseUrl;
          return response;
        }
      } catch (error) {
        lastError = error;
      }
    }

    if (lastResponse != null) return lastResponse;
    throw RadioBrowserException(
      'Radio Browser request failed${lastError == null ? '' : ': $lastError'}',
    );
  }

  Future<List<String>> _resolveBaseUrls() {
    final cached = _baseUrls;
    if (cached != null) return Future.value(cached);

    return _baseUrlsFuture ??= _discoverBaseUrls();
  }

  Future<List<String>> _discoverBaseUrls() async {
    final discovered = <String>{};
    try {
      final response = await _client
          .get(Uri.parse(_serverDiscoveryUrl), headers: _headers)
          .timeout(_requestTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is List) {
          for (final item in data) {
            if (item is! Map<String, dynamic>) continue;
            final host = (item['name'] as String? ?? '').trim();
            final uri = Uri.tryParse('https://$host');
            if (uri != null && uri.host == host && uri.host.isNotEmpty) {
              discovered.add(uri.origin);
            }
          }
        }
      }
    } catch (_) {
      // A known public mirror is appended below.
    }

    discovered.add(_fallbackBaseUrl);
    final result = discovered.toList(growable: false);
    _baseUrls = result;
    _baseUrlsFuture = null;
    return result;
  }

  Map<String, String> get _headers => const {
    'Accept': 'application/json',
    'User-Agent': 'StreamBeat/0.1.0 (flow-music)',
  };

  Map<String, String> get _imageHeaders => const {
    'Accept': 'image/*,*/*;q=0.8',
    'User-Agent': 'StreamBeat/0.1.0 (flow-music)',
  };

  Future<void> _checkAvailable(RadioStation station) async {
    if (station.isCustomStation) return;
    final removals = await removalsRepository.load();
    if (removals.contains(station)) throw const StationUnavailableException();
  }

  void _checkResolvedUrl(RadioStation station, String url) {
    if (!station.isCustomStation && removalsRepository.current.blocksUrl(url)) {
      throw const StationUnavailableException();
    }
  }

  bool _canUseStreamUrl(String value) {
    if (!RadioStation.isPlayableUrl(value)) return false;
    return !_requireHttps ||
        Uri.parse(value.trim()).scheme.toLowerCase() == 'https';
  }

  Never _throwIncompatibleStream() {
    throw const RadioBrowserException(
      'The station does not provide a stream compatible with this platform',
    );
  }
}

bool isRadioStationUuid(String value) {
  return RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(value.trim());
}

class RadioBrowserException implements Exception {
  const RadioBrowserException(this.message);

  final String message;

  @override
  String toString() => message;
}
