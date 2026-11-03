import 'package:flow_music/features/monetization/domain/repositories/subscription_repository.dart';
import 'package:flutter/foundation.dart';

/// Inicializa las compras con la identidad que conserva el SDK de la tienda.
class MonetizationCoordinator {
  MonetizationCoordinator(this._subscriptions);

  final SubscriptionRepository _subscriptions;

  Future<void> initialize() async {
    try {
      await _subscriptions.initialize();
    } catch (error, stackTrace) {
      debugPrint('Unable to initialize purchases: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
