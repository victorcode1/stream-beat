import 'package:flow_music/features/settings/data/settings_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final subscriptionPromoCoordinatorProvider =
    Provider<SubscriptionPromoCoordinator>((_) {
      return SubscriptionPromoCoordinator(Hive.box(settingsBoxName));
    });

class SubscriptionPromoCoordinator {
  SubscriptionPromoCoordinator(this._box);

  static const minimumLaunches = 3;
  static const minimumInterval = Duration(days: 7);
  static const _launchCountKey = 'subscription_promo_launch_count';
  static const _lastShownAtKey = 'subscription_promo_last_shown_at_ms';

  final Box _box;

  Future<void> recordLaunch() async {
    final current = _box.get(_launchCountKey);
    final count = current is int ? current : 0;
    await _box.put(_launchCountKey, count + 1);
  }

  bool shouldShow({DateTime? now}) {
    final rawLaunchCount = _box.get(_launchCountKey);
    final launchCount = rawLaunchCount is int ? rawLaunchCount : 0;
    if (launchCount < minimumLaunches) return false;

    final rawLastShownAt = _box.get(_lastShownAtKey);
    if (rawLastShownAt is! int) return true;
    final lastShownAt = DateTime.fromMillisecondsSinceEpoch(rawLastShownAt);
    return (now ?? DateTime.now()).difference(lastShownAt) >= minimumInterval;
  }

  Future<void> markShown({DateTime? now}) {
    return _box.put(
      _lastShownAtKey,
      (now ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }
}
