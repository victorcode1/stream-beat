import 'package:flow_music/features/monetization/domain/entities/subscription_access.dart';
import 'package:flow_music/features/monetization/domain/repositories/subscription_repository.dart';

class UnavailableSubscriptionRepository implements SubscriptionRepository {
  const UnavailableSubscriptionRepository();

  static const _failure = SubscriptionFailure(
    'Las suscripciones todavia no estan configuradas.',
  );

  @override
  bool get isAvailable => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<PremiumOffer>> loadOffers() => Future.error(_failure);

  @override
  Future<SubscriptionAccess> purchase(PremiumOfferKind kind) =>
      Future.error(_failure);

  @override
  Future<SubscriptionAccess> refresh() async =>
      const SubscriptionAccess.unavailable();

  @override
  Future<SubscriptionAccess> restore() => Future.error(_failure);

  @override
  Stream<SubscriptionAccess> watchAccess() =>
      Stream.value(const SubscriptionAccess.unavailable());

  @override
  void dispose() {}
}
