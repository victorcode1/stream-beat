import 'dart:async';

import 'package:flow_music/features/daily_recommendations/data/daily_station_payload.dart';
import 'package:flow_music/features/daily_recommendations/domain/daily_recommendation_plan.dart';
import 'package:flow_music/features/daily_recommendations/domain/repositories/daily_recommendation_repository.dart';
import 'package:flow_music/features/home/data/home_suggestions_repository.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/domain/station_directory_mode.dart';
import 'package:flow_music/features/settings/data/settings_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const _enabledKey = 'daily_radio_recommendations_enabled';
const _notificationIdStart = 731000;
const _scheduledDays = 30;
const _notificationHour = 18;

class LocalDailyRecommendationRepository
    implements DailyRecommendationRepository {
  LocalDailyRecommendationRepository({
    FlutterLocalNotificationsPlugin? notifications,
    HomeSuggestionsRepository Function()? suggestionsRepositoryFactory,
  }) : _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
       _suggestionsRepositoryFactory =
           suggestionsRepositoryFactory ?? HomeSuggestionsRepository.new;

  final FlutterLocalNotificationsPlugin _notifications;
  final HomeSuggestionsRepository Function() _suggestionsRepositoryFactory;
  final StreamController<RadioStation> _openedStations =
      StreamController<RadioStation>.broadcast();

  Future<void>? _initialization;
  RadioStation? _initialStation;

  /// Recomendar emisoras del directorio solo en Android: iOS no propone
  /// emisoras por su cuenta (ver [stationDirectoryIsSearchFirst]).
  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  bool get isEnabled {
    if (!Hive.isBoxOpen(settingsBoxName)) return false;
    return Hive.box(settingsBoxName).get(_enabledKey) == true;
  }

  @override
  Stream<RadioStation> get openedStations => _openedStations.stream;

  @override
  Future<void> initialize() {
    if (!isSupported) return Future.value();
    return _initialization ??= _initializePlugin();
  }

  Future<void> _initializePlugin() async {
    tz_data.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    } catch (error) {
      debugPrint('Unable to resolve local timezone: $error');
    }

    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    final launchDetails = await _notifications
        .getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _initialStation = DailyStationPayload.decode(
        launchDetails?.notificationResponse?.payload,
      );
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final station = DailyStationPayload.decode(response.payload);
    if (station != null && !_openedStations.isClosed) {
      _openedStations.add(station);
    }
  }

  @override
  RadioStation? takeInitialStation() {
    final station = _initialStation;
    _initialStation = null;
    return station;
  }

  @override
  Future<DailyRecommendationToggleResult> setEnabled(
    bool enabled, {
    required String languageCode,
  }) async {
    if (!isSupported) return DailyRecommendationToggleResult.unavailable;
    try {
      await initialize();
      if (!enabled) {
        await _cancelScheduledNotifications();
        await Hive.box(settingsBoxName).put(_enabledKey, false);
        return DailyRecommendationToggleResult.disabled;
      }

      if (!await _requestPermission()) {
        return DailyRecommendationToggleResult.permissionDenied;
      }
      if (!await _schedule(languageCode: languageCode)) {
        return DailyRecommendationToggleResult.failed;
      }
      await Hive.box(settingsBoxName).put(_enabledKey, true);
      return DailyRecommendationToggleResult.enabled;
    } catch (error, stackTrace) {
      debugPrint('Unable to update daily recommendations: $error');
      debugPrintStack(stackTrace: stackTrace);
      return DailyRecommendationToggleResult.failed;
    }
  }

  Future<bool> _requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? true;
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

  @override
  Future<void> refresh({required String languageCode}) async {
    if (!isSupported || !isEnabled) return;
    try {
      await initialize();
      await _schedule(languageCode: languageCode);
    } catch (error, stackTrace) {
      debugPrint('Unable to refresh daily recommendations: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> _schedule({required String languageCode}) async {
    final suggestionsRepository = _suggestionsRepositoryFactory();
    try {
      final suggestions = await suggestionsRepository.load(limit: 60);
      final now = tz.TZDateTime.now(tz.local);
      final plan = buildDailyRecommendationPlan(
        stations: suggestions.stations,
        now: DateTime(
          now.year,
          now.month,
          now.day,
          now.hour,
          now.minute,
          now.second,
        ),
        days: _scheduledDays,
        hour: _notificationHour,
      );
      if (plan.isEmpty) return false;

      await _cancelScheduledNotifications();
      try {
        for (final (index, slot) in plan.indexed) {
          final station = slot.station;
          await _notifications.zonedSchedule(
            id: _notificationIdStart + index,
            scheduledDate: tz.TZDateTime(
              tz.local,
              slot.scheduledAt.year,
              slot.scheduledAt.month,
              slot.scheduledAt.day,
              slot.scheduledAt.hour,
            ),
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'daily_station_recommendations',
                'Recomendaciones de emisoras',
                channelDescription:
                    'Una recomendación opcional de radio al día',
                importance: Importance.defaultImportance,
                priority: Priority.defaultPriority,
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentSound: true,
                presentBadge: false,
                threadIdentifier: 'daily_station_recommendations',
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            title: _titleFor(languageCode),
            body: _bodyFor(station, languageCode),
            payload: DailyStationPayload.encode(station),
          );
        }
        return true;
      } catch (_) {
        await _cancelScheduledNotifications();
        rethrow;
      }
    } finally {
      suggestionsRepository.close();
    }
  }

  String _titleFor(String languageCode) => switch (languageCode) {
    'es' => 'Una emisora para ti 🎧',
    'pt' => 'Uma estação para você 🎧',
    _ => 'A station for you 🎧',
  };

  String _bodyFor(RadioStation station, String languageCode) {
    final country = station.country.trim();
    if (languageCode == 'es') {
      return country.isEmpty
          ? 'Descubre ${station.name} y empieza a escuchar.'
          : 'Descubre ${station.name}, una radio de $country.';
    }
    if (languageCode == 'pt') {
      return country.isEmpty
          ? 'Descubra ${station.name} e comece a ouvir.'
          : 'Descubra ${station.name}, uma rádio de $country.';
    }
    return country.isEmpty
        ? 'Discover ${station.name} and start listening.'
        : 'Discover ${station.name}, live from $country.';
  }

  Future<void> _cancelScheduledNotifications() async {
    for (var index = 0; index < _scheduledDays; index++) {
      await _notifications.cancel(id: _notificationIdStart + index);
    }
  }

  @override
  void dispose() {
    unawaited(_openedStations.close());
  }
}
