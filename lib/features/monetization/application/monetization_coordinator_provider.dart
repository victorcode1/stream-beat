import 'package:flow_music/features/monetization/application/monetization_coordinator.dart';
import 'package:flow_music/features/monetization/presentation/providers/monetization_providers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final monetizationCoordinatorProvider = Provider<MonetizationCoordinator>((
  ref,
) {
  final coordinator = MonetizationCoordinator(
    ref.watch(subscriptionRepositoryProvider),
  );
  return coordinator;
});
