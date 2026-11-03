import 'dart:async';

import 'package:flow_music/features/monetization/domain/entities/subscription_access.dart';
import 'package:flow_music/features/monetization/presentation/providers/ad_providers.dart';
import 'package:flow_music/features/monetization/presentation/providers/monetization_providers.dart';
import 'package:flow_music/features/monetization/presentation/widgets/respectful_banner_slot.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// The SDK manager exposes the ads created by the real widget for callbacks.
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  late StreamController<SubscriptionAccess> access;
  num? adaptiveHeight;

  setUp(() async {
    calls.clear();
    adaptiveHeight = 90;
    access = StreamController<SubscriptionAccess>();
    instanceManager = AdInstanceManager('plugins.flutter.io/google_mobile_ads');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      instanceManager.channel,
      (call) async {
        calls.add(call);
        if (call.method == 'AdSize#getLargeAnchoredAdaptiveBannerAdSize') {
          return adaptiveHeight;
        }
        return null;
      },
    );
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  tearDown(() async {
    await access.close();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      instanceManager.channel,
      null,
    );
  });

  Future<void> mount(WidgetTester tester, {bool consent = true}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionAccessProvider.overrideWith((ref) => access.stream),
          canRequestAdsProvider.overrideWith((ref) async => consent),
        ],
        child: const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RespectfulBannerSlot(),
                SizedBox(key: Key('controls'), height: 64),
              ],
            ),
          ),
        ),
      ),
    );
    access.add(const SubscriptionAccess.free());
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  Map<dynamic, dynamic> loadedSize() {
    final args =
        calls.lastWhere((call) => call.method == 'loadBannerAd').arguments
            as Map;
    final size = args['size'] as AdSize;
    return {'width': size.width, 'height': size.height};
  }

  BannerAd currentAd() {
    final id =
        (calls.lastWhere((call) => call.method == 'loadBannerAd').arguments
                as Map)['adId']
            as int;
    return instanceManager.adFor(id)! as BannerAd;
  }

  testWidgets(
    'reserves stable space, loads without audio handler, releases on background and premium',
    (tester) async {
      await mount(tester);
      expect(calls.where((c) => c.method == 'loadBannerAd'), hasLength(1));
      final position = tester.getTopLeft(find.byKey(const Key('controls')));
      final ad = currentAd();
      ad.listener.onAdLoaded!(ad);
      await tester.pump();
      expect(find.byType(AdWidget), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(const Key('controls'))), position);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(calls.where((c) => c.method == 'disposeAd'), hasLength(1));
      expect(tester.getTopLeft(find.byKey(const Key('controls'))), position);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls.where((c) => c.method == 'loadBannerAd'), hasLength(2));
      access.add(
        const SubscriptionAccess(
          isResolved: true,
          serviceAvailable: true,
          isActive: true,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(calls.where((c) => c.method == 'disposeAd'), hasLength(2));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('requests a full-width adaptive banner and reserves its height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await mount(tester);
    // The codec sends only the width; the SDK resolves the same height natively.
    expect(loadedSize()['width'], 412);
    expect(
      (calls.lastWhere((c) => c.method == 'loadBannerAd').arguments
          as Map)['size'],
      isA<AnchoredAdaptiveBannerAdSize>(),
    );
    expect(tester.getSize(find.byType(RespectfulBannerSlot)).height, 114);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('falls back to the standard banner without adaptive size', (
    tester,
  ) async {
    adaptiveHeight = null;
    await mount(tester);
    expect(loadedSize(), {
      'width': AdSize.banner.width,
      'height': AdSize.banner.height,
    });
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('does not request ads without consent', (tester) async {
    await mount(tester, consent: false);
    expect(calls.where((c) => c.method == 'loadBannerAd'), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'retries a failed request after a minute and cancels retry in background',
    (tester) async {
      await mount(tester);
      final ad = currentAd();
      ad.listener.onAdFailedToLoad!(
        ad,
        LoadAdError(3, 'test', 'No fill', null),
      );
      await tester.pump(const Duration(seconds: 59));
      expect(calls.where((c) => c.method == 'loadBannerAd'), hasLength(1));
      await tester.pump(const Duration(seconds: 1));
      expect(calls.where((c) => c.method == 'loadBannerAd'), hasLength(2));
      final second = currentAd();
      second.listener.onAdFailedToLoad!(
        second,
        LoadAdError(3, 'test', 'No fill', null),
      );
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump(const Duration(minutes: 2));
      expect(calls.where((c) => c.method == 'loadBannerAd'), hasLength(2));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
