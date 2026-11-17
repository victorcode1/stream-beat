import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flow_music/features/monetization/data/ad_revenue_tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('purchases_flutter');
  final calls = <MethodCall>[];
  var configured = true;
  var fail = false;

  setUp(() {
    calls.clear();
    configured = true;
    fail = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'isConfigured') return configured;
          if (fail) throw PlatformException(code: 'unavailable');
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  BannerAd banner() => BannerAd(
    adUnitId: 'test-banner',
    size: AdSize.banner,
    request: const AdRequest(),
    listener: const BannerAdListener(),
  );

  test(
    'preserves micros, currency, precision and impression identity',
    () async {
      final tracker = AdRevenueTracker(placement: 'home_banner');
      final ad = banner();
      await tracker.loaded(ad);
      await tracker.displayed(ad);
      await tracker.paid(ad, 12345, PrecisionType.precise, 'USD');
      await tracker.opened(ad);
      expect(calls.map((call) => call.method), [
        'trackAdLoaded',
        'trackAdDisplayed',
        'trackAdRevenue',
        'trackAdOpened',
      ]);
      final data = calls[2].arguments as Map;
      expect(data['revenueMicros'], 12345);
      expect(data['currency'], 'USD');
      expect(data['precision'], 'exact');
      expect(data['mediatorName'], 'AdMob');
      expect(data['placement'], 'home_banner');
      expect(
        calls.map((call) => (call.arguments as Map)['impressionId']).toSet(),
        hasLength(1),
      );
      final firstId = data['impressionId'];
      await tracker.loaded(ad);
      expect((calls.last.arguments as Map)['impressionId'], isNot(firstId));
    },
  );

  test('skips unconfigured tracking and contains native failures', () async {
    final tracker = AdRevenueTracker(placement: 'home_banner');
    configured = false;
    await tracker.loaded(banner());
    expect(calls, isEmpty);
    configured = true;
    fail = true;
    await tracker.displayed(banner());
    expect(calls, isEmpty);
  });

  test(
    'does not report invalid revenue and keeps zero-value test events',
    () async {
      final tracker = AdRevenueTracker(placement: 'home_banner');
      final ad = banner();
      await tracker.paid(ad, double.nan, PrecisionType.unknown, 'USD');
      await tracker.paid(ad, -1, PrecisionType.unknown, 'USD');
      expect(calls, isEmpty);
      await tracker.paid(ad, 0, PrecisionType.estimated, 'USD');
      expect((calls.single.arguments as Map)['revenueMicros'], 0);
      expect((calls.single.arguments as Map)['precision'], 'estimated');
    },
  );
}
