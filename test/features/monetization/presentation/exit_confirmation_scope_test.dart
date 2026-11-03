import 'package:flow_music/core/audio/audio_playing_provider.dart';
import 'package:flow_music/features/monetization/domain/entities/subscription_access.dart';
import 'package:flow_music/features/monetization/presentation/controllers/exit_ad_controller.dart';
import 'package:flow_music/features/monetization/presentation/providers/ad_providers.dart';
import 'package:flow_music/features/monetization/presentation/providers/monetization_providers.dart';
import 'package:flow_music/features/monetization/presentation/widgets/exit_confirmation_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  late _FakeExitAds ads;
  late int exits;

  setUp(() {
    ads = _FakeExitAds();
    exits = 0;
  });

  Future<void> mount(
    WidgetTester tester, {
    bool playing = false,
    bool consent = true,
    SubscriptionAccess access = const SubscriptionAccess.free(),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionAccessProvider.overrideWith(
            (ref) => Stream.value(access),
          ),
          canRequestAdsProvider.overrideWith((ref) async => consent),
          audioPlayingProvider.overrideWith((ref) => Stream.value(playing)),
          exitAdControllerProvider.overrideWithValue(ads),
        ],
        child: MaterialApp(
          home: ExitConfirmationScope(
            onExit: () async => exits++,
            child: const Scaffold(body: Text('home')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  bool canPop(WidgetTester tester) => tester
      .widget<PopScope>(
        find.descendant(
          of: find.byType(ExitConfirmationScope),
          matching: find.byWidgetPredicate((widget) => widget is PopScope),
        ),
      )
      .canPop;

  testWidgets('asks before closing for free users who are not listening', (
    tester,
  ) async {
    await mount(tester);
    expect(canPop(tester), isFalse);
    expect(ads.preloads, greaterThan(0));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('exit_dialog_title'), findsOneWidget);
    // No loaded ad: the dialog never reserves an empty ad area.
    expect(find.byKey(const Key('exit-ad')), findsNothing);

    await tester.tap(find.byKey(const Key('exit-cancel')));
    await tester.pumpAndSettle();
    expect(exits, 0);
    expect(find.text('home'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exit-confirm')));
    await tester.pumpAndSettle();
    expect(exits, 1);
  }, variant: TargetPlatformVariant({TargetPlatform.android}));

  testWidgets('lets Back close the app while the radio plays', (tester) async {
    await mount(tester, playing: true);
    expect(canPop(tester), isTrue);
    expect(ads.preloads, 0);
  }, variant: TargetPlatformVariant({TargetPlatform.android}));

  testWidgets('never asks supporters or users without ad consent', (
    tester,
  ) async {
    await mount(
      tester,
      access: const SubscriptionAccess(
        isResolved: true,
        serviceAvailable: true,
        isActive: true,
      ),
    );
    expect(canPop(tester), isTrue);
    await mount(tester, consent: false);
    expect(canPop(tester), isTrue);
  }, variant: TargetPlatformVariant({TargetPlatform.android}));

  testWidgets('does not intercept Back on iOS', (tester) async {
    await mount(tester);
    expect(canPop(tester), isTrue);
  }, variant: TargetPlatformVariant({TargetPlatform.iOS}));
}

class _FakeExitAds implements ExitAdController {
  int preloads = 0;

  @override
  void preload() => preloads++;

  @override
  BannerAd? takeLoaded() => null;

  @override
  void dispose() {}
}
