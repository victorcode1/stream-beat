import 'dart:io';

import 'package:flow_music/core/engagement/subscription_promo_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory tempDirectory;
  late Box<dynamic> box;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('streambeat_promo_');
    Hive.init(tempDirectory.path);
    box = await Hive.openBox<dynamic>('subscription_promo_test');
  });

  tearDown(() async {
    await Hive.close();
    await tempDirectory.delete(recursive: true);
  });

  test('waits until the third launch', () async {
    final coordinator = SubscriptionPromoCoordinator(box);

    await coordinator.recordLaunch();
    await coordinator.recordLaunch();
    expect(coordinator.shouldShow(), isFalse);

    await coordinator.recordLaunch();
    expect(coordinator.shouldShow(), isTrue);
  });

  test('shows at most once every 7 days', () async {
    final coordinator = SubscriptionPromoCoordinator(box);
    final firstShownAt = DateTime(2026, 1, 1);
    for (var index = 0; index < 3; index++) {
      await coordinator.recordLaunch();
    }
    await coordinator.markShown(now: firstShownAt);

    expect(
      coordinator.shouldShow(now: firstShownAt.add(const Duration(days: 6))),
      isFalse,
    );
    expect(
      coordinator.shouldShow(now: firstShownAt.add(const Duration(days: 7))),
      isTrue,
    );
  });
}
