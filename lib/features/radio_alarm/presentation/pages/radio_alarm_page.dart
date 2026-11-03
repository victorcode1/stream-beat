import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/history/data/playback_history_entry.dart';
import 'package:flow_music/features/history/presentation/controllers/playback_history_controller.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/presentation/controllers/radio_favorites_controller.dart';
import 'package:flow_music/features/radio/presentation/controllers/radio_queue_controller.dart';
import 'package:flow_music/features/radio_alarm/data/radio_alarm_repository.dart';
import 'package:flow_music/features/radio_alarm/domain/radio_alarm.dart';
import 'package:flow_music/features/radio_alarm/presentation/providers/radio_alarm_providers.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Settings row that opens the alarm editor and shows when it rings.
class RadioAlarmEntry extends ConsumerWidget {
  const RadioAlarmEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alarm = ref.watch(radioAlarmControllerProvider);
    final subtitle = alarm != null && alarm.enabled
        ? describeAlarmTime(context, alarm)
        : LocaleKeys.radio_alarm_off.tr();
    return Card(
      child: ListTile(
        key: const Key('radio-alarm-entry'),
        leading: const Icon(Icons.alarm_rounded),
        title: Text(LocaleKeys.radio_alarm_title.tr()),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const RadioAlarmPage())),
      ),
    );
  }
}

/// Spanish and English show a.m./p.m.; Portuguese (Brazil) uses 24 hours.
bool _uses12Hours(Locale locale) => locale.languageCode != 'pt';

String formatAlarmClock(BuildContext context, DateTime time) {
  final locale = context.locale.toLanguageTag();
  final pattern = _uses12Hours(context.locale) ? 'h:mm a' : 'HH:mm';
  return DateFormat(pattern, locale).format(time);
}

String formatAlarmMoment(BuildContext context, DateTime time) {
  final day = DateFormat.MMMEd(context.locale.toLanguageTag()).format(time);
  return '$day, ${formatAlarmClock(context, time)}';
}

String describeAlarmTime(BuildContext context, RadioAlarm alarm) {
  final next = alarm.nextTrigger(DateTime.now());
  return LocaleKeys.radio_alarm_next.tr(
    args: [formatAlarmMoment(context, next)],
  );
}

class RadioAlarmPage extends ConsumerStatefulWidget {
  const RadioAlarmPage({super.key});

  @override
  ConsumerState<RadioAlarmPage> createState() => _RadioAlarmPageState();
}

class _RadioAlarmPageState extends ConsumerState<RadioAlarmPage> {
  late TimeOfDay _time;
  late Set<int> _weekdays;
  RadioStation? _station;
  late bool _enabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final alarm = ref.read(radioAlarmControllerProvider);
    _time = alarm == null
        ? const TimeOfDay(hour: 6, minute: 30)
        : TimeOfDay(hour: alarm.hour, minute: alarm.minute);
    _weekdays = {
      ...(alarm?.weekdays ??
          const {
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
          }),
    };
    _station = alarm?.station;
    _enabled = alarm?.enabled ?? false;
  }

  /// The chosen station, the one playing now, favorites, then recent plays.
  List<RadioStation> _candidates() {
    final current = ref.watch(radioQueueControllerProvider).current;
    final favorites = ref.watch(radioFavoritesControllerProvider);
    final recent = ref
        .watch(playbackHistoryControllerProvider)
        .map(_stationFromHistory)
        .whereType<RadioStation>()
        .take(5);
    final stations = <RadioStation>[];
    for (final station in [_station, current, ...favorites, ...recent]) {
      if (station == null || !station.isPlayable) continue;
      if (stations.any((item) => _sameStation(item, station))) continue;
      stations.add(station);
    }
    return stations;
  }

  static RadioStation? _stationFromHistory(PlaybackHistoryEntry entry) {
    if (entry.stationData.isEmpty) return null;
    try {
      return RadioStation.fromJson(entry.stationData);
    } catch (_) {
      return null;
    }
  }

  static bool _sameStation(RadioStation a, RadioStation? b) {
    if (b == null) return false;
    if (a.stationUuid.isNotEmpty) return a.stationUuid == b.stationUuid;
    return a.streamUrl == b.streamUrl;
  }

  RadioAlarm? _draft({bool? enabled}) {
    final station = _station;
    if (station == null) return null;
    return RadioAlarm(
      enabled: enabled ?? _enabled,
      hour: _time.hour,
      minute: _time.minute,
      weekdays: _weekdays,
      station: station,
    );
  }

  Future<void> _save({bool? enabled}) async {
    final alarm = _draft(enabled: enabled);
    if (alarm == null) return;
    setState(() => _saving = true);
    final result = await ref
        .read(radioAlarmControllerProvider.notifier)
        .save(alarm, languageCode: context.locale.languageCode);
    if (!mounted) return;
    final saved = ref.read(radioAlarmControllerProvider);
    setState(() {
      _saving = false;
      _enabled = saved?.enabled ?? false;
    });
    final message = switch (result) {
      RadioAlarmSaveResult.scheduled when enabled == true =>
        LocaleKeys.radio_alarm_saved.tr(
          args: [formatAlarmMoment(context, alarm.nextTrigger(DateTime.now()))],
        ),
      RadioAlarmSaveResult.scheduledInexact =>
        LocaleKeys.radio_alarm_inexact.tr(),
      RadioAlarmSaveResult.permissionDenied =>
        LocaleKeys.radio_alarm_permission_denied.tr(),
      RadioAlarmSaveResult.failed ||
      RadioAlarmSaveResult.unavailable => LocaleKeys.radio_alarm_failed.tr(),
      _ => null,
    };
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Edits reschedule an active alarm; a disabled one is only stored.
  void _changed(VoidCallback update) {
    setState(update);
    unawaited(_save(enabled: _enabled ? true : null));
  }

  Future<void> _pickTime() async {
    final locale = context.locale;
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) {
        if (!_uses12Hours(locale)) return child!;
        // Spanish Material formats default to 24 hours; es-US keeps Spanish
        // text with an a.m./p.m. selector.
        final pickerLocale = locale.languageCode == 'es'
            ? const Locale('es', 'US')
            : const Locale('en', 'US');
        return Localizations.override(
          context: context,
          locale: pickerLocale,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
            child: child!,
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    _changed(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final stations = _candidates();
    _station ??= stations.isEmpty ? null : stations.first;
    final alarm = _draft();
    final locale = context.locale.toLanguageTag();
    final weekdayFormat = DateFormat.E(locale);
    // 2024-01-01 was a Monday.
    final weekdays = [
      for (var day = DateTime.monday; day <= DateTime.sunday; day++)
        (day, weekdayFormat.format(DateTime(2024, 1, day))),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.radio_alarm_title.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: TextButton(
              key: const Key('radio-alarm-time'),
              onPressed: _saving ? null : _pickTime,
              child: Text(
                formatAlarmClock(
                  context,
                  DateTime(2024, 1, 1, _time.hour, _time.minute),
                ),
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
            ),
          ),
          if (alarm != null && _enabled)
            Text(
              describeAlarmTime(context, alarm),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.primary,
              ),
            ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            key: const Key('radio-alarm-switch'),
            title: Text(LocaleKeys.radio_alarm_switch.tr()),
            subtitle: Text(LocaleKeys.radio_alarm_hint.tr()),
            value: _enabled,
            onChanged: _saving || alarm == null
                ? null
                : (value) {
                    setState(() => _enabled = value);
                    unawaited(_save(enabled: value));
                  },
          ),
          const SizedBox(height: 16),
          Text(
            LocaleKeys.radio_alarm_repeat.tr(),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (day, label) in weekdays)
                FilterChip(
                  key: Key('radio-alarm-day-$day'),
                  label: Text(label),
                  selected: _weekdays.contains(day),
                  onSelected: _saving
                      ? null
                      : (selected) => _changed(() {
                          _weekdays = {..._weekdays};
                          selected ? _weekdays.add(day) : _weekdays.remove(day);
                        }),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _weekdays.isEmpty
                ? LocaleKeys.radio_alarm_once.tr()
                : _weekdays.length == DateTime.daysPerWeek
                ? LocaleKeys.radio_alarm_daily.tr()
                : '',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            LocaleKeys.radio_alarm_station.tr(),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          if (stations.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                LocaleKeys.radio_alarm_no_favorites.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            )
          else
            RadioGroup<String>(
              groupValue: _stationKey(_station),
              onChanged: (key) {
                if (_saving || key == null) return;
                final station = stations.firstWhere(
                  (item) => _stationKey(item) == key,
                );
                _changed(() => _station = station);
              },
              child: Column(
                children: [
                  for (final station in stations)
                    RadioListTile<String>(
                      key: Key('radio-alarm-station-${_stationKey(station)}'),
                      value: _stationKey(station),
                      title: Text(station.name),
                      subtitle: station.country.isEmpty
                          ? null
                          : Text(station.country),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _stationKey(RadioStation? station) {
    if (station == null) return '';
    return station.stationUuid.isNotEmpty
        ? station.stationUuid
        : station.streamUrl;
  }
}
