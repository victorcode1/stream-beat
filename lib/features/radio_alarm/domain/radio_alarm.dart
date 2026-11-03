import 'package:flow_music/features/radio/data/models/radio_station.dart';

/// A wake-up alarm that opens StreamBeat and plays [station].
class RadioAlarm {
  const RadioAlarm({
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.weekdays,
    required this.station,
  });

  final bool enabled;
  final int hour;
  final int minute;

  /// [DateTime.monday]..[DateTime.sunday]. Empty means it rings once.
  final Set<int> weekdays;
  final RadioStation station;

  bool get repeats => weekdays.isNotEmpty;
  bool get daily => weekdays.length == DateTime.daysPerWeek;

  RadioAlarm copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    Set<int>? weekdays,
    RadioStation? station,
  }) {
    return RadioAlarm(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      weekdays: weekdays ?? this.weekdays,
      station: station ?? this.station,
    );
  }

  /// The next time this alarm rings after [now].
  DateTime nextTrigger(DateTime now) {
    if (!repeats) return nextOccurrence(now: now, hour: hour, minute: minute);
    return weekdays
        .map(
          (weekday) => nextOccurrence(
            now: now,
            hour: hour,
            minute: minute,
            weekday: weekday,
          ),
        )
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  Map<String, dynamic> toJson() => {
    'v': 1,
    'enabled': enabled,
    'hour': hour,
    'minute': minute,
    'weekdays': (weekdays.toList()..sort()),
    'station': station.toJson(),
  };

  static RadioAlarm? fromJson(Object? json) {
    if (json is! Map || json['v'] != 1) return null;
    final stationJson = json['station'];
    final hour = json['hour'];
    final minute = json['minute'];
    if (stationJson is! Map || hour is! int || minute is! int) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    try {
      final station = RadioStation.fromJson(
        Map<String, dynamic>.from(stationJson),
      );
      if (!station.isPlayable) return null;
      final weekdays = (json['weekdays'] as List? ?? const [])
          .whereType<int>()
          .where((day) => day >= DateTime.monday && day <= DateTime.sunday)
          .toSet();
      return RadioAlarm(
        enabled: json['enabled'] == true,
        hour: hour,
        minute: minute,
        weekdays: weekdays,
        station: station,
      );
    } catch (_) {
      return null;
    }
  }
}

/// The first [hour]:[minute] strictly after [now], optionally on [weekday].
DateTime nextOccurrence({
  required DateTime now,
  required int hour,
  required int minute,
  int? weekday,
}) {
  var candidate = DateTime(now.year, now.month, now.day, hour, minute);
  if (weekday != null) {
    final days = (weekday - candidate.weekday) % DateTime.daysPerWeek;
    candidate = DateTime(
      candidate.year,
      candidate.month,
      candidate.day + days,
      hour,
      minute,
    );
  }
  if (!candidate.isAfter(now)) {
    final step = weekday == null ? 1 : DateTime.daysPerWeek;
    candidate = DateTime(
      candidate.year,
      candidate.month,
      candidate.day + step,
      hour,
      minute,
    );
  }
  return candidate;
}
