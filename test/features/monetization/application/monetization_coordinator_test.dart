import 'package:flow_music/features/monetization/application/monetization_coordinator.dart';
import 'package:flow_music/features/monetization/domain/entities/subscription_access.dart';
import 'package:flow_music/features/monetization/domain/repositories/subscription_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts purchases without authentication or profiles', () async {
    final subscriptions = _TrackingSubscriptionRepository();
    await MonetizationCoordinator(subscriptions).initialize();
    expect(subscriptions.initializeCalls, 1);
  });

  test('store failure does not prevent startup and can be retried', () async {
    final subscriptions = _TrackingSubscriptionRepository()..fail = true;
    final coordinator = MonetizationCoordinator(subscriptions);
    await coordinator.initialize();
    subscriptions.fail = false;
    await coordinator.initialize();
    expect(subscriptions.initializeCalls, 2);
  });
}

class _TrackingSubscriptionRepository implements SubscriptionRepository {
  int initializeCalls = 0;
  bool fail = false;

  @override
  bool get isAvailable => true;

  @override
  void dispose() {}

  @override
  Future<void> initialize() async {
    initializeCalls++;
    if (fail) throw StateError('store unavailable');
  }

  @override
  Future<List<PremiumOffer>> loadOffers() => throw UnimplementedError();

  @override
  Future<SubscriptionAccess> purchase(PremiumOfferKind kind) =>
      throw UnimplementedError();

  @override
  Future<SubscriptionAccess> refresh() async => const SubscriptionAccess.free();

  @override
  Future<SubscriptionAccess> restore() => throw UnimplementedError();

  @override
  Stream<SubscriptionAccess> watchAccess() =>
      Stream.value(const SubscriptionAccess.free());
}
