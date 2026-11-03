import 'package:flow_music/features/daily_recommendations/data/daily_station_payload.dart';
import 'package:flow_music/features/radio_alarm/domain/radio_alarm.dart';
import 'package:flow_music/features/settings/data/settings_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

enum RadioAlarmSaveResult {
  scheduled,

  /// Android did not grant exact alarms: it may ring a few minutes late.
  scheduledInexact,
  disabled,
  permissionDenied,
  unavailable,
  failed,
}

/// Stores the alarm and schedules it as an alarm-style local notification.
///
/// Tapping the notification reuses the station payload of the daily
/// recommendations, so StreamBeat opens the player and starts the station.
class RadioAlarmRepository {
  RadioAlarmRepository({
    required Future<void> Function() ensureNotificationsReady,
    FlutterLocalNotificationsPlugin? notifications,
    DateTime Function()? now,
  }) : _ensureNotificationsReady = ensureNotificationsReady,
       _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
       _now = now ?? DateTime.now;

  static const _alarmKey = 'radio_alarm_v1';
  static const _onceAtKey = 'radio_alarm_once_at_ms';
  static const _idStart = 732000;
  static const _channelId = 'radio_alarm';

  /// Android's FLAG_INSISTENT: the alarm sound repeats until it is handled.
  static const _flagInsistent = 4;

  final Future<void> Function() _ensureNotificationsReady;
  final FlutterLocalNotificationsPlugin _notifications;
  final DateTime Function() _now;

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Box get _box => Hive.box(settingsBoxName);

  RadioAlarm? load() {
    if (!Hive.isBoxOpen(settingsBoxName)) return null;
    final alarm = RadioAlarm.fromJson(_box.get(_alarmKey));
    if (alarm == null || !alarm.enabled || alarm.repeats) return alarm;
    // A one-time alarm that already rang shows as switched off.
    final onceAt = _box.get(_onceAtKey);
    if (onceAt is int &&
        !DateTime.fromMillisecondsSinceEpoch(onceAt).isAfter(_now())) {
      return alarm.copyWith(enabled: false);
    }
    return alarm;
  }

  Future<RadioAlarmSaveResult> save(
    RadioAlarm alarm, {
    required String languageCode,
  }) async {
    if (!isSupported) return RadioAlarmSaveResult.unavailable;
    try {
      await _ensureNotificationsReady();
      await _cancelAll();
      if (!alarm.enabled) {
        await _persist(alarm, onceAt: null);
        return RadioAlarmSaveResult.disabled;
      }
      if (!await _requestNotificationPermission()) {
        await _persist(alarm.copyWith(enabled: false), onceAt: null);
        return RadioAlarmSaveResult.permissionDenied;
      }
      final exact = await _ensureExactAlarms();
      final mode = exact
          ? AndroidScheduleMode.alarmClock
          : AndroidScheduleMode.inexactAllowWhileIdle;
      final onceAt = await _schedule(alarm, mode, languageCode);
      await _persist(alarm, onceAt: onceAt);
      return exact
          ? RadioAlarmSaveResult.scheduled
          : RadioAlarmSaveResult.scheduledInexact;
    } catch (error, stackTrace) {
      debugPrint('Unable to schedule the radio alarm: $error');
      debugPrintStack(stackTrace: stackTrace);
      return RadioAlarmSaveResult.failed;
    }
  }

  Future<DateTime?> _schedule(
    RadioAlarm alarm,
    AndroidScheduleMode mode,
    String languageCode,
  ) async {
    final now = _now();
    Future<void> schedule(int id, DateTime at, DateTimeComponents? match) {
      return _notifications.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime(
          tz.local,
          at.year,
          at.month,
          at.day,
          at.hour,
          at.minute,
        ),
        notificationDetails: _details,
        androidScheduleMode: mode,
        title: _title(languageCode),
        body: _body(alarm.station.name, languageCode),
        payload: DailyStationPayload.encode(alarm.station),
        matchDateTimeComponents: match,
      );
    }

    if (!alarm.repeats) {
      final at = alarm.nextTrigger(now);
      await schedule(_idStart, at, null);
      return at;
    }
    if (alarm.daily) {
      await schedule(_idStart, alarm.nextTrigger(now), DateTimeComponents.time);
      return null;
    }
    for (final weekday in alarm.weekdays) {
      final at = nextOccurrence(
        now: now,
        hour: alarm.hour,
        minute: alarm.minute,
        weekday: weekday,
      );
      await schedule(
        _idStart + weekday,
        at,
        DateTimeComponents.dayOfWeekAndTime,
      );
    }
    return null;
  }

  Future<void> _persist(RadioAlarm alarm, {required DateTime? onceAt}) async {
    await _box.put(_alarmKey, alarm.toJson());
    if (onceAt == null) {
      await _box.delete(_onceAtKey);
    } else {
      await _box.put(_onceAtKey, onceAt.millisecondsSinceEpoch);
    }
  }

  Future<void> _cancelAll() async {
    for (var offset = 0; offset <= DateTime.sunday; offset++) {
      await _notifications.cancel(id: _idStart + offset);
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<bool> _requestNotificationPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _android?.requestNotificationsPermission() ?? true;
    }
    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          sound: true,
          badge: false,
        ) ??
        false;
  }

  Future<bool> _ensureExactAlarms() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    final android = _android;
    if (android == null) return false;
    if (await android.canScheduleExactNotifications() ?? false) return true;
    await android.requestExactAlarmsPermission();
    return await android.canScheduleExactNotifications() ?? false;
  }

  static final _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Despertador',
      channelDescription: 'Despertador con tu emisora favorita',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      sound: const UriAndroidNotificationSound(
        'content://settings/system/alarm_alert',
      ),
      additionalFlags: Int32List.fromList([_flagInsistent]),
      ticker: 'StreamBeat',
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: false,
      threadIdentifier: _channelId,
    ),
  );

  String _title(String languageCode) => switch (languageCode) {
    'es' => '⏰ Despertador StreamBeat',
    'pt' => '⏰ Despertador StreamBeat',
    _ => '⏰ StreamBeat alarm',
  };

  String _body(String station, String languageCode) => switch (languageCode) {
    'es' => 'Buenos días. Toca para escuchar $station.',
    'pt' => 'Bom dia. Toque para ouvir $station.',
    _ => 'Good morning. Tap to listen to $station.',
  };
}
