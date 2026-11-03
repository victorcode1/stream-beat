import 'package:flow_music/features/daily_recommendations/presentation/providers/daily_recommendation_providers.dart';
import 'package:flow_music/features/radio_alarm/data/radio_alarm_repository.dart';
import 'package:flow_music/features/radio_alarm/domain/radio_alarm.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final radioAlarmRepositoryProvider = Provider<RadioAlarmRepository>((ref) {
  // Both features share the plugin, initialized once by the daily repository.
  final daily = ref.watch(dailyRecommendationRepositoryProvider);
  return RadioAlarmRepository(ensureNotificationsReady: daily.initialize);
});

final radioAlarmControllerProvider =
    NotifierProvider<RadioAlarmController, RadioAlarm?>(
      RadioAlarmController.new,
    );

class RadioAlarmController extends Notifier<RadioAlarm?> {
  @override
  RadioAlarm? build() => ref.watch(radioAlarmRepositoryProvider).load();

  bool get isSupported => ref.read(radioAlarmRepositoryProvider).isSupported;

  Future<RadioAlarmSaveResult> save(
    RadioAlarm alarm, {
    required String languageCode,
  }) async {
    state = alarm;
    final repository = ref.read(radioAlarmRepositoryProvider);
    final result = await repository.save(alarm, languageCode: languageCode);
    state = repository.load();
    return result;
  }
}
