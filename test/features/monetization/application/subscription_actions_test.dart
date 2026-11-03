import 'package:flow_music/features/monetization/application/subscription_actions.dart';
import 'package:flow_music/features/monetization/domain/entities/subscription_access.dart';
import 'package:flow_music/features/monetization/domain/repositories/subscription_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final kind in PremiumOfferKind.values) {
    test('purchase $kind without an account grants permanent access', () async {
      final subscriptions = _FakeSubscriptionRepository();
      final access = await SubscriptionActions(subscriptions).purchase(kind);
      expect(subscriptions.initializeCalls, 1);
      expect(subscriptions.purchasedKinds, [kind]);
      expect(access.isActive, isTrue);
      expect(access.expiresAt, isNull);
    });
  }

  test('restore queries store access without registration', () async {
    final subscriptions = _FakeSubscriptionRepository();
    final access = await SubscriptionActions(subscriptions).restore();
    expect(subscriptions.initializeCalls, 1);
    expect(subscriptions.restoreCalls, 1);
    expect(access.isActive, isTrue);
  });
}

class _FakeSubscriptionRepository implements SubscriptionRepository {
  int initializeCalls = 0;
  int restoreCalls = 0;
  final purchasedKinds = <PremiumOfferKind>[];

  @override
  bool get isAvailable => true;

  @override
  void dispose() {}

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }

  @override
  Future<List<PremiumOffer>> loadOffers() async => const [
    PremiumOffer(
      kind: PremiumOfferKind.small,
      productId: 'streambeat_support_small',
      priceLabel: r'$0.99',
      period: 'P1M',
    ),
    PremiumOffer(
      kind: PremiumOfferKind.large,
      productId: 'streambeat_support_large',
      priceLabel: r'$9.99',
    ),
  ];

  @override
  Future<SubscriptionAccess> purchase(PremiumOfferKind kind) async {
    purchasedKinds.add(kind);
    return SubscriptionAccess(
      isResolved: true,
      serviceAvailable: true,
      isActive: true,
      productId: kind == PremiumOfferKind.large
          ? 'streambeat_support_large'
          : 'streambeat_support_small',
    );
  }

  @override
  Future<SubscriptionAccess> refresh() async => const SubscriptionAccess.free();

  @override
  Future<SubscriptionAccess> restore() async {
    restoreCalls++;
    return const SubscriptionAccess(
      isResolved: true,
      serviceAvailable: true,
      isActive: true,
    );
  }

  @override
  Stream<SubscriptionAccess> watchAccess() =>
      Stream.value(const SubscriptionAccess.free());
}
