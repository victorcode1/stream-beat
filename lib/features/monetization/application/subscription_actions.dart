import 'package:flow_music/features/monetization/domain/entities/subscription_access.dart';
import 'package:flow_music/features/monetization/domain/repositories/subscription_repository.dart';

class SubscriptionActions {
  const SubscriptionActions(this._subscriptions);

  final SubscriptionRepository _subscriptions;

  Future<SubscriptionAccess> purchase(PremiumOfferKind kind) async {
    await _subscriptions.initialize();
    return _subscriptions.purchase(kind);
  }

  Future<SubscriptionAccess> restore() async {
    await _subscriptions.initialize();
    return _subscriptions.restore();
  }
}
