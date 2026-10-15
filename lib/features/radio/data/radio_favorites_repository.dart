import 'dart:convert';

import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

const String radioFavoritesBoxName = 'radio_favorites';
// Ignore metadata left by older versions without deleting local data.
const String _legacyOwnerUidKey = '__owner_uid';
const String _addedAtKey = '__favorited_at';

/// Persistencia local de las emisoras marcadas como favoritas.
///
/// Cada entrada guarda `RadioStation.rawData` con un campo extra
/// `__favorited_at` (ISO 8601) para ordenar los favoritos locales por fecha.
class RadioFavoritesRepository {
  const RadioFavoritesRepository();

  Box get _box => Hive.box(radioFavoritesBoxName);

  List<RadioStation> readAll() {
    final stations = <RadioStation>[];
    for (final key in _box.keys) {
      if (key == _legacyOwnerUidKey) continue;
      final station = _decode(_box.get(key));
      if (station != null) stations.add(station);
    }
    stations.sort((a, b) {
      final aAt = favoritedAt(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bAt = favoritedAt(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final cmp = bAt.compareTo(aAt);
      if (cmp != 0) return cmp;
      return a.name.compareTo(b.name);
    });
    return List.unmodifiable(stations);
  }

  Future<bool> toggle(RadioStation station) async {
    final key = keyFor(station);
    if (key.isEmpty) return false;
    if (_box.containsKey(key)) {
      await _box.delete(key);
      return false;
    }
    await _box.put(key, jsonEncode(_stamp(station, DateTime.now())));
    return true;
  }

  bool contains(RadioStation station) {
    final key = keyFor(station);
    return key.isNotEmpty && _box.containsKey(key);
  }

  Future<void> remove(String stationId) async {
    if (stationId.isEmpty) return;
    await _box.delete(stationId);
  }

  static String keyFor(RadioStation station) {
    if (station.stationUuid.isNotEmpty) return station.stationUuid;
    return station.streamUrl;
  }

  static DateTime? favoritedAt(RadioStation station) {
    final raw = station.rawData[_addedAtKey];
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  Map<String, dynamic> _stamp(RadioStation station, DateTime at) {
    final data = Map<String, dynamic>.from(station.rawData);
    data[_addedAtKey] = at.toIso8601String();
    return data;
  }

  RadioStation? _decode(Object? raw) {
    try {
      if (raw is! String || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return RadioStation.fromJson(decoded);
    } catch (error, stackTrace) {
      debugPrint('RadioFavoritesRepository decode failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }
}
