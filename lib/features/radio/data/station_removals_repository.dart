import 'dart:convert';

import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/settings/data/settings_storage.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

class StationRemovals {
  const StationRemovals({
    this.stationUuids = const {},
    this.streamHosts = const {},
  });

  factory StationRemovals.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 ||
        json['updatedAt'] is! String ||
        DateTime.tryParse(json['updatedAt'] as String) == null) {
      throw const FormatException('Invalid station removal manifest');
    }
    Set<String> readList(String key) {
      final values = json[key];
      if (values is! List || values.any((value) => value is! String)) {
        throw FormatException('Invalid $key');
      }
      return Set.unmodifiable(
        values
            .cast<String>()
            .map((value) => value.trim().toLowerCase())
            .where((value) => value.isNotEmpty),
      );
    }

    return StationRemovals(
      stationUuids: readList('stationUuids'),
      streamHosts: readList('streamHosts'),
    );
  }

  final Set<String> stationUuids;
  final Set<String> streamHosts;

  bool contains(RadioStation station) {
    if (station.isCustomStation) return false;
    return stationUuids.contains(station.stationUuid.trim().toLowerCase()) ||
        blocksUrl(station.url) ||
        blocksUrl(station.urlResolved);
  }

  bool blocksUrl(String value) =>
      streamHosts.contains(Uri.tryParse(value.trim())?.host.toLowerCase());
}

/// A device-wide manifest independent of account data. Startup launches [load]
/// without awaiting the network; directory requests and playback await at most
/// the short timeout. Failed attempts are also throttled for six hours.
class StationRemovalsRepository {
  StationRemovalsRepository({
    http.Client? client,
    String? Function()? readCache,
    Future<void> Function(String)? writeCache,
    Future<String> Function()? loadAsset,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 3),
  }) : _client = client ?? http.Client(),
       _readCache = readCache ?? _readHive,
       _writeCache = writeCache ?? _writeHive,
       _loadAsset =
           loadAsset ??
           (() => rootBundle.loadString('assets/station_removals.json')),
       _now = now ?? DateTime.now;

  static final instance = StationRemovalsRepository();
  static final endpoint = Uri.parse(
    'https://victorcode1.github.io/stream-beat/station-removals.json',
  );
  static const refreshInterval = Duration(hours: 6);
  static const _cacheKey = 'station_removals_v1';
  static const _emptyManifest = <String, dynamic>{
    'version': 1,
    'updatedAt': '1970-01-01T00:00:00Z',
    'stationUuids': <String>[],
    'streamHosts': <String>[],
  };

  final http.Client _client;
  final String? Function() _readCache;
  final Future<void> Function(String) _writeCache;
  final Future<String> Function() _loadAsset;
  final DateTime Function() _now;
  final Duration timeout;
  StationRemovals _current = const StationRemovals();
  StationRemovals get current => _current;
  Map<String, dynamic> _manifest = _emptyManifest;
  DateTime? _checkedAt;
  bool _localLoaded = false;
  Future<StationRemovals>? _pending;

  Future<StationRemovals> load() =>
      _pending ??= _load().whenComplete(() => _pending = null);

  Future<StationRemovals> _load() async {
    if (!_localLoaded) {
      var hasCache = false;
      try {
        final raw = _readCache();
        if (raw != null) {
          final cache = jsonDecode(raw) as Map<String, dynamic>;
          final manifest = Map<String, dynamic>.from(cache['data'] as Map);
          _current = StationRemovals.fromJson(manifest);
          _manifest = manifest;
          _checkedAt = DateTime.tryParse(cache['checkedAt'] as String);
          hasCache = true;
        }
      } catch (_) {
        // A damaged cache must not prevent loading the bundled fallback.
      }
      if (!hasCache) {
        try {
          final manifest =
              jsonDecode(await _loadAsset()) as Map<String, dynamic>;
          _current = StationRemovals.fromJson(manifest);
          _manifest = manifest;
        } catch (_) {
          _current = const StationRemovals();
        }
      }
      _localLoaded = true;
    }
    final now = _now().toUtc();
    if (_checkedAt != null && now.difference(_checkedAt!) < refreshInterval) {
      return current;
    }
    _checkedAt = now;
    try {
      final response = await _client.get(endpoint).timeout(timeout);
      if (response.statusCode == 404) {
        _manifest = _emptyManifest;
        _current = const StationRemovals();
      } else if (response.statusCode == 200) {
        final manifest = jsonDecode(response.body) as Map<String, dynamic>;
        final parsed = StationRemovals.fromJson(manifest);
        _manifest = manifest;
        _current = parsed;
      }
    } catch (_) {
      // Keep the last valid cache or bundled asset, including on timeout.
    }
    try {
      await _writeCache(
        jsonEncode({'checkedAt': now.toIso8601String(), 'data': _manifest}),
      );
    } catch (_) {
      // Storage failures do not interrupt browsing or playback.
    }
    return current;
  }

  static String? _readHive() => Hive.isBoxOpen(settingsBoxName)
      ? Hive.box(settingsBoxName).get(_cacheKey) as String?
      : null;
  static Future<void> _writeHive(String value) async {
    if (Hive.isBoxOpen(settingsBoxName)) {
      await Hive.box(settingsBoxName).put(_cacheKey, value);
    }
  }
}

class StationUnavailableException implements Exception {
  const StationUnavailableException();
}
