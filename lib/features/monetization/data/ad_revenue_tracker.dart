import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Manual tracking keeps compatibility with Google Mobile Ads 9.x.
final class AdRevenueTracker {
  AdRevenueTracker({required this.placement});

  final String placement;
  final _random = Random.secure();
  String? _impressionId;

  String _id(Ad ad) => _impressionId ??=
      ad.responseInfo?.responseId ??
      List.generate(
        16,
        (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();

  String? _network(Ad ad) =>
      ad.responseInfo?.loadedAdapterResponseInfo?.adSourceName;

  Future<void> loaded(Ad ad) {
    // An auto-refresh reuses the banner object but starts a new impression.
    _impressionId = null;
    final data = AdLoadedData(
      networkName: _network(ad),
      mediatorName: AdMediatorName.adMob,
      adFormat: AdFormat.banner,
      placement: placement,
      adUnitId: ad.adUnitId,
      impressionId: _id(ad),
    );
    return _send(() => Purchases.adTracker.trackAdLoaded(data));
  }

  Future<void> displayed(Ad ad) {
    final data = AdDisplayedData(
      networkName: _network(ad),
      mediatorName: AdMediatorName.adMob,
      adFormat: AdFormat.banner,
      placement: placement,
      adUnitId: ad.adUnitId,
      impressionId: _id(ad),
    );
    return _send(() => Purchases.adTracker.trackAdDisplayed(data));
  }

  Future<void> opened(Ad ad) {
    final data = AdOpenedData(
      networkName: _network(ad),
      mediatorName: AdMediatorName.adMob,
      adFormat: AdFormat.banner,
      placement: placement,
      adUnitId: ad.adUnitId,
      impressionId: _id(ad),
    );
    return _send(() => Purchases.adTracker.trackAdOpened(data));
  }

  Future<void> paid(
    Ad ad,
    double micros,
    PrecisionType precision,
    String currency,
  ) async {
    if (!micros.isFinite || micros < 0 || currency.isEmpty) return;
    final data = AdRevenueData(
      networkName: _network(ad),
      mediatorName: AdMediatorName.adMob,
      adFormat: AdFormat.banner,
      placement: placement,
      adUnitId: ad.adUnitId,
      impressionId: _id(ad),
      revenueMicros: micros.round(),
      currency: currency,
      precision: switch (precision) {
        PrecisionType.precise => AdRevenuePrecision.exact,
        PrecisionType.estimated => AdRevenuePrecision.estimated,
        PrecisionType.publisherProvided => AdRevenuePrecision.publisherDefined,
        PrecisionType.unknown => AdRevenuePrecision.unknown,
      },
    );
    await _send(() => Purchases.adTracker.trackAdRevenue(data));
  }

  Future<void> failed(Ad ad, LoadAdError error) => _send(
    () => Purchases.adTracker.trackAdFailedToLoad(
      AdFailedToLoadData(
        mediatorName: AdMediatorName.adMob,
        adFormat: AdFormat.banner,
        placement: placement,
        adUnitId: ad.adUnitId,
        mediatorErrorCode: error.code,
      ),
    ),
  );

  Future<void> _send(Future<void> Function() event) async {
    try {
      if (await Purchases.isConfigured) await event();
    } on Object catch (error) {
      // Analytics must never interrupt displaying or disposing an ad.
      debugPrint('RevenueCat ad tracking: $error');
    }
  }
}
