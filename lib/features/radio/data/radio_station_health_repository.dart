import 'dart:convert';

import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

const String radioStationHealthBoxName = 'radio_station_health';

@immutable
class RadioStationHealth {
  const RadioStationHealth({
    this.consecutiveFailures = 0,
    this.lastFailure,
    this.lastSuccess,
    this.lastErrorType,
  });

  factory RadioStationHealth.fromJson(Map<String, dynamic> json) {
    return RadioStationHealth(
      consecutiveFailures: _parseInt(json['consecutiveFailures']),
      lastFailure: _parseDateTime(json['lastFailure']),
      lastSuccess: _parseDateTime(json['lastSuccess']),
      lastErrorType: json['lastErrorType'] as String?,
    );
  }

  final int consecutiveFailures;
  final DateTime? lastFailure;
  final DateTime? lastSuccess;
  final String? lastErrorType;

  bool isTemporarilySuppressed(
    DateTime now, {
    Duration cooldown = const Duration(hours: 12),
  }) {
    final failure = lastFailure;
    return consecutiveFailures >= 2 &&
        failure != null &&
        now.difference(failure) < cooldown;
  }

  Map<String, dynamic> toJson() => {
    'consecutiveFailures': consecutiveFailures,
    if (lastFailure != null) 'lastFailure': lastFailure!.toIso8601String(),
    if (lastSuccess != null) 'lastSuccess': lastSuccess!.toIso8601String(),
    if (lastErrorType != null) 'lastErrorType': lastErrorType,
  };
}

/// Local reliability signal layered on top of Radio Browser's global checks.
///
/// Radio streams frequently change between directory checks. Keeping a small,
/// device-local success/failure history lets StreamBeat demote providers that
/// are failing for this particular platform or network without deleting them.
class RadioStationHealthRepository {
  RadioStationHealthRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  Box? get _box => Hive.isBoxOpen(radioStationHealthBoxName)
      ? Hive.box(radioStationHealthBoxName)
      : null;

  RadioStationHealth read(RadioStation station) {
    if (station.isCustomStation) return const RadioStationHealth();
    final key = keyFor(station);
    final box = _box;
    if (key.isEmpty || box == null) return const RadioStationHealth();

    try {
      final raw = box.get(key);
      if (raw is! String || raw.isEmpty) return const RadioStationHealth();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const RadioStationHealth();
      }
      return RadioStationHealth.fromJson(decoded);
    } catch (error) {
      debugPrint('Unable to read radio station health: $error');
      return const RadioStationHealth();
    }
  }

  Future<void> recordSuccess(RadioStation station) async {
    if (station.isCustomStation) return;
    final key = keyFor(station);
    final box = _box;
    if (key.isEmpty || box == null) return;
    final current = read(station);
    final updated = RadioStationHealth(
      lastSuccess: _now().toUtc(),
      lastFailure: current.lastFailure,
    );
    try {
      await box.put(key, jsonEncode(updated.toJson()));
    } catch (error) {
      debugPrint('Unable to store radio station success: $error');
    }
  }

  Future<void> recordFailure(RadioStation station, [Object? error]) async {
    if (station.isCustomStation) return;
    final key = keyFor(station);
    final box = _box;
    if (key.isEmpty || box == null) return;
    final current = read(station);
    final updated = RadioStationHealth(
      consecutiveFailures: current.consecutiveFailures + 1,
      lastFailure: _now().toUtc(),
      lastSuccess: current.lastSuccess,
      lastErrorType: error?.runtimeType.toString(),
    );
    try {
      await box.put(key, jsonEncode(updated.toJson()));
    } catch (writeError) {
      debugPrint('Unable to store radio station failure: $writeError');
    }
  }

  bool isTemporarilySuppressed(RadioStation station) {
    return read(station).isTemporarilySuppressed(_now().toUtc());
  }

  List<RadioStation> rank(Iterable<RadioStation> stations) {
    final now = _now().toUtc();
    final ranked = stations.toList(growable: false);
    ranked.sort((a, b) {
      final scoreComparison = _score(b, now).compareTo(_score(a, now));
      if (scoreComparison != 0) return scoreComparison;
      final clicksComparison = b.clickCount.compareTo(a.clickCount);
      if (clicksComparison != 0) return clicksComparison;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return ranked;
  }

  int _score(RadioStation station, DateTime now) {
    var score = 0;
    if (station.isHttps) score += 30;
    if (station.lastCheckOk == 1) score += 30;
    if (station.hasSslError) score -= 80;
    if (station.isHls) score -= 5;

    final checkedAt = station.lastCheckOkTime ?? station.lastCheckTime;
    if (checkedAt != null) {
      final age = now.difference(checkedAt);
      if (age <= const Duration(days: 7)) {
        score += 30;
      } else if (age <= const Duration(days: 30)) {
        score += 20;
      } else if (age <= const Duration(days: 180)) {
        score += 5;
      } else {
        score -= 20;
      }
    }

    final local = read(station);
    final success = local.lastSuccess;
    if (success != null) {
      final age = now.difference(success);
      if (age <= const Duration(days: 7)) {
        score += 80;
      } else if (age <= const Duration(days: 30)) {
        score += 40;
      }
    }
    score -= local.consecutiveFailures * 80;
    if (local.isTemporarilySuppressed(now)) score -= 1000;
    return score;
  }

  static String keyFor(RadioStation station) {
    return station.stationUuid.isNotEmpty
        ? station.stationUuid
        : station.streamUrl;
  }
}

int _parseInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}
