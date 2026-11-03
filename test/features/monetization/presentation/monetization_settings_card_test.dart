import 'package:flow_music/features/monetization/domain/entities/subscription_access.dart';
import 'package:flow_music/features/monetization/domain/repositories/subscription_repository.dart';
import 'package:flow_music/features/monetization/presentation/providers/ad_providers.dart';
import 'package:flow_music/features/monetization/presentation/providers/monetization_providers.dart';
import 'package:flow_music/features/monetization/presentation/widgets/monetization_settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  const launcher = MethodChannel('plugins.flutter.io/url_launcher');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcher, null);
  });

  Future<_TrackingSubscriptionRepository> pumpCard(
    WidgetTester tester, {
    List<PremiumOffer> offers = const [
      PremiumOffer(
        kind: PremiumOfferKind.small,
        productId: 'streambeat_support_small',
        priceLabel: r'$0.99',
      ),
      PremiumOffer(
        kind: PremiumOfferKind.medium,
        productId: 'streambeat_support_medium',
        priceLabel: r'$2.99',
      ),
      PremiumOffer(
        kind: PremiumOfferKind.large,
        productId: 'streambeat_support_large',
        priceLabel: r'$4.99',
      ),
    ],
    SubscriptionAccess access = const SubscriptionAccess.free(),
  }) async {
    final subscriptions = _TrackingSubscriptionRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionRepositoryProvider.overrideWithValue(subscriptions),
          subscriptionAccessProvider.overrideWith(
            (ref) => Stream.value(access),
          ),
          premiumOffersProvider.overrideWith((ref) async => offers),
          privacyOptionsRequiredProvider.overrideWith((ref) async => false),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: MonetizationSettingsCard()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return subscriptions;
  }

  testWidgets('external support opens Ko-fi without purchasing ad removal', (
    tester,
  ) async {
    MethodCall? launched;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcher, (call) async {
          launched = call;
          return true;
        });
    final subscriptions = await pumpCard(tester);
    final button = find.byKey(const Key('external-support'));
    expect(button, findsOneWidget);
    expect(find.text('external_support_disclosure'), findsOneWidget);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(launched?.method, 'launch');
    expect(launched?.arguments['url'], 'https://ko-fi.com/streambeat');
    expect(launched?.arguments['useWebView'], false);
    expect(launched?.arguments['useSafariVC'], false);
    expect(subscriptions.purchasedKinds, isEmpty);
    expect(subscriptions.restoreCalls, 0);
  }, variant: TargetPlatformVariant({TargetPlatform.windows}));

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    testWidgets('external support is hidden on $platform', (tester) async {
      await pumpCard(tester);
      expect(find.byKey(const Key('external-support')), findsNothing);
      expect(find.text('restore_purchase'), findsOneWidget);
    }, variant: TargetPlatformVariant({platform}));
  }

  for (final throws in [false, true]) {
    testWidgets('external support reports launch failure (throws: $throws)', (
      tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(launcher, (call) async {
            if (throws) throw PlatformException(code: 'launch_failed');
            return false;
          });
      await pumpCard(tester);
      final button = find.byKey(const Key('external-support'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('subscription_link_failed'), findsOneWidget);
    }, variant: TargetPlatformVariant({TargetPlatform.windows}));
  }

  testWidgets('contributions and restore have no account controls', (
    tester,
  ) async {
    await pumpCard(tester);
    expect(find.text('auth_sign_in_button'), findsNothing);
    expect(find.text('auth_sign_out'), findsNothing);
    expect(find.text('auth_delete_account'), findsNothing);
    expect(find.text('account_subscription_reason'), findsNothing);
    expect(find.text('restore_purchase'), findsOneWidget);
    expect(find.byKey(const ValueKey('contribution-small')), findsOneWidget);
  });

  testWidgets(
    'offers three contribution amounts without subscriptions or lifetime sale',
    (tester) async {
      await pumpCard(tester);

      expect(find.byKey(const ValueKey('contribution-small')), findsOneWidget);
      expect(find.byKey(const ValueKey('contribution-large')), findsOneWidget);
      expect(find.byKey(const ValueKey('contribution-medium')), findsOneWidget);
      expect(find.text('subscribe_monthly_action'), findsNothing);
      expect(find.text('buy_lifetime_action'), findsNothing);
      expect(find.text('retry'), findsNothing);
    },
  );

  for (final kind in PremiumOfferKind.values) {
    testWidgets('guest $kind purchase opens store without account sheet', (
      tester,
    ) async {
      final subscriptions = await pumpCard(tester);
      final button = find.byKey(ValueKey('contribution-${kind.name}'));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(subscriptions.purchasedKinds, [kind]);
    });
  }

  testWidgets('guest restores without registration', (tester) async {
    final subscriptions = await pumpCard(tester);
    await tester.tap(find.text('restore_purchase'));
    await tester.pumpAndSettle();
    expect(subscriptions.restoreCalls, 1);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('does not offer a purchase without store prices', (tester) async {
    await pumpCard(tester, offers: const []);
    expect(find.byKey(const ValueKey('contribution-small')), findsNothing);
    expect(find.byKey(const ValueKey('contribution-large')), findsNothing);
    expect(find.text('retry'), findsOneWidget);
    expect(find.text('restore_purchase'), findsOneWidget);
  });

  testWidgets('routes large contribution to its store package', (tester) async {
    final subscriptions = await pumpCard(tester);

    await tester.tap(find.byKey(const ValueKey('contribution-large')));
    await tester.pumpAndSettle();

    expect(subscriptions.purchasedKinds, [PremiumOfferKind.large]);
  });

  testWidgets('offers retry while contribution products are propagating', (
    tester,
  ) async {
    await pumpCard(
      tester,
      offers: const [
        PremiumOffer(
          kind: PremiumOfferKind.small,
          productId: 'remove_ads_monthly',
          priceLabel: r'$0.99',
          period: 'P1M',
        ),
      ],
    );

    expect(find.text('retry'), findsOneWidget);
    expect(find.byKey(const ValueKey('contribution-large')), findsNothing);
  });

  testWidgets(
    'historical owners retain access without being asked to contribute',
    (tester) async {
      await pumpCard(
        tester,
        access: const SubscriptionAccess(
          isResolved: true,
          serviceAvailable: true,
          isActive: true,
          productId: 'remove_ads_lifetime',
        ),
      );

      expect(find.byKey(const ValueKey('contribution-small')), findsNothing);
      expect(find.byKey(const ValueKey('contribution-large')), findsNothing);
    },
  );

  testWidgets('historical monthly subscribers are not asked to buy again', (
    tester,
  ) async {
    await pumpCard(
      tester,
      access: const SubscriptionAccess(
        isResolved: true,
        serviceAvailable: true,
        isActive: true,
        userId: 'test-user',
        productId: 'remove_ads_monthly',
        hasMonthlySubscription: true,
      ),
    );
    expect(find.byKey(const ValueKey('contribution-small')), findsNothing);
    expect(find.byKey(const ValueKey('contribution-large')), findsNothing);
    expect(find.byKey(const Key('cloud-sync-status')), findsNothing);
    expect(find.byKey(const Key('cloud-library-details')), findsNothing);
    expect(find.byIcon(Icons.cloud_outlined), findsNothing);
    expect(find.byKey(const Key('export-local-library')), findsOneWidget);
  });
}

class _TrackingSubscriptionRepository implements SubscriptionRepository {
  final purchasedKinds = <PremiumOfferKind>[];
  int restoreCalls = 0;

  @override
  bool get isAvailable => true;

  @override
  void dispose() {}

  @override
  Future<void> initialize() async {}

  @override
  Future<List<PremiumOffer>> loadOffers() async => const [];

  @override
  Future<SubscriptionAccess> purchase(PremiumOfferKind kind) async {
    purchasedKinds.add(kind);
    return SubscriptionAccess(
      isResolved: true,
      serviceAvailable: true,
      isActive: true,
      productId: 'streambeat_support_${kind.name}',
    );
  }

  @override
  Future<SubscriptionAccess> refresh() async => const SubscriptionAccess.free();

  @override
  Future<SubscriptionAccess> restore() async {
    restoreCalls++;
    return const SubscriptionAccess.free();
  }

  @override
  Stream<SubscriptionAccess> watchAccess() =>
      Stream.value(const SubscriptionAccess.free());
}
