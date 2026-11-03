import 'package:flow_music/features/monetization/domain/entities/subscription_access.dart';

abstract interface class SubscriptionRepository {
  bool get isAvailable;

  Stream<SubscriptionAccess> watchAccess();

  Future<void> initialize();

  Future<List<PremiumOffer>> loadOffers();

  Future<SubscriptionAccess> purchase(PremiumOfferKind kind);

  Future<SubscriptionAccess> restore();

  Future<SubscriptionAccess> refresh();

  void dispose();
}

class SubscriptionFailure implements Exception {
  const SubscriptionFailure(this.message, {this.cancelled = false});

  final String message;
  final bool cancelled;

  @override
  String toString() => message;
}
