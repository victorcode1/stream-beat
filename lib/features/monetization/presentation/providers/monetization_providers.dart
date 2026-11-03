import 'package:flow_music/features/monetization/application/subscription_actions.dart';
import 'package:flow_music/features/monetization/data/revenuecat_subscription_repository.dart';
import 'package:flow_music/features/monetization/data/unavailable_subscription_repository.dart';
import 'package:flow_music/features/monetization/domain/entities/subscription_access.dart';
import 'package:flow_music/features/monetization/domain/repositories/subscription_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final repository = RevenueCatSubscriptionRepository();
  if (!repository.isAvailable) {
    repository.dispose();
    return const UnavailableSubscriptionRepository();
  }
  ref.onDispose(repository.dispose);
  return repository;
});

final subscriptionAccessProvider = StreamProvider<SubscriptionAccess>((ref) {
  return ref.watch(subscriptionRepositoryProvider).watchAccess();
});

final premiumOffersProvider = FutureProvider<List<PremiumOffer>>((ref) {
  return ref.watch(subscriptionRepositoryProvider).loadOffers();
});

final subscriptionActionsProvider = Provider<SubscriptionActions>((ref) {
  return SubscriptionActions(ref.watch(subscriptionRepositoryProvider));
});
