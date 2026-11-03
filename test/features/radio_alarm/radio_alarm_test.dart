import 'dart:io';

import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio_alarm/data/radio_alarm_repository.dart';
import 'package:flow_music/features/radio_alarm/domain/radio_alarm.dart';
import 'package:flow_music/features/settings/data/settings_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

final _station = RadioStation.fromJson(const {
  'stationuuid': 'abc',
  'name': 'Radio Prueba',
  'url': 'https://stream.example.com/live',
  'url_resolved': 'https://stream.example.com/live',
  'country': 'Panamá',
});

RadioAlarm _alarm({Set<int> weekdays = const {}, bool enabled = true}) =>
    RadioAlarm(
      enabled: enabled,
      hour: 6,
      minute: 30,
      weekdays: weekdays,
      station: _station,
    );

void main() {
  group('nextOccurrence', () {
    // 2026-11-03 is a Tuesday.
    final now = DateTime(2026, 11, 3, 7);

    test('rolls a passed time to tomorrow', () {
      expect(
        nextOccurrence(now: now, hour: 6, minute: 30),
        DateTime(2026, 11, 4, 6, 30),
      );
      expect(
        nextOccurrence(now: now, hour: 7, minute: 30),
        DateTime(2026, 11, 3, 7, 30),
      );
    });

    test('finds the next matching weekday', () {
      expect(
        nextOccurrence(now: now, hour: 6, minute: 30, weekday: DateTime.friday),
        DateTime(2026, 11, 6, 6, 30),
      );
      // Same weekday but already past: next week.
      expect(
        nextOccurrence(
          now: now,
          hour: 6,
          minute: 30,
          weekday: DateTime.tuesday,
        ),
        DateTime(2026, 11, 10, 6, 30),
      );
    });

    test('alarm picks the earliest selected weekday', () {
      final alarm = _alarm(weekdays: {DateTime.monday, DateTime.thursday});
      expect(alarm.nextTrigger(now), DateTime(2026, 11, 5, 6, 30));
    });
  });

  test('round-trips through storage json', () {
    final alarm = _alarm(weekdays: {DateTime.saturday, DateTime.monday});
    final restored = RadioAlarm.fromJson(alarm.toJson())!;
    expect(restored.enabled, isTrue);
    expect(restored.hour, 6);
    expect(restored.minute, 30);
    expect(restored.weekdays, {DateTime.monday, DateTime.saturday});
    expect(restored.station.name, 'Radio Prueba');
    expect(RadioAlarm.fromJson({'v': 2}), isNull);
    expect(RadioAlarm.fromJson({...alarm.toJson(), 'hour': 25}), isNull);
  });

  group('repository', () {
    late Directory directory;
    late Box<dynamic> box;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('streambeat_alarm_');
      Hive.init(directory.path);
      box = await Hive.openBox<dynamic>(settingsBoxName);
    });

    tearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });

    RadioAlarmRepository repository(DateTime now) => RadioAlarmRepository(
      ensureNotificationsReady: () async {},
      now: () => now,
    );

    test('a one-time alarm that already rang loads as off', () async {
      await box.put('radio_alarm_v1', _alarm().toJson());
      await box.put(
        'radio_alarm_once_at_ms',
        DateTime(2026, 11, 4, 6, 30).millisecondsSinceEpoch,
      );
      expect(repository(DateTime(2026, 11, 4, 6)).load()!.enabled, isTrue);
      expect(repository(DateTime(2026, 11, 4, 7)).load()!.enabled, isFalse);
    });

    test('repeating alarms stay on', () async {
      await box.put(
        'radio_alarm_v1',
        _alarm(weekdays: {DateTime.monday}).toJson(),
      );
      expect(repository(DateTime(2030)).load()!.enabled, isTrue);
    });
  });
}
