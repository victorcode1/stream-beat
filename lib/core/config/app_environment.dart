import 'package:flutter/foundation.dart';

/// Configuracion publica inyectada en compilacion con `--dart-define`.
///
/// Las claves de RevenueCat y AdMob usadas por el cliente son
/// identificadores publicos. Las claves administrativas y secretos de webhook
/// nunca deben agregarse a esta clase ni al binario de la aplicacion.
class AppEnvironment {
  const AppEnvironment();

  static const revenueCatAndroidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
  );
  static const revenueCatIosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_API_KEY',
  );
  static const revenueCatEntitlementId = String.fromEnvironment(
    'REVENUECAT_ENTITLEMENT_ID',
    defaultValue: 'remove_ads',
  );
  static const revenueCatOfferingId = String.fromEnvironment(
    'REVENUECAT_OFFERING_ID',
    defaultValue: 'support',
  );
  // Recognize historical monthly purchases without offering new subscriptions.
  static const revenueCatMonthlyProductId = String.fromEnvironment(
    'REVENUECAT_MONTHLY_PRODUCT_ID',
    defaultValue: 'remove_ads_monthly',
  );
  static const revenueCatContributionSmallProductId = String.fromEnvironment(
    'REVENUECAT_CONTRIBUTION_SMALL_PRODUCT_ID',
    defaultValue: 'streambeat_support_small',
  );
  static const revenueCatContributionMediumProductId = String.fromEnvironment(
    'REVENUECAT_CONTRIBUTION_MEDIUM_PRODUCT_ID',
    defaultValue: 'streambeat_support_medium',
  );
  static const revenueCatContributionLargeProductId = String.fromEnvironment(
    'REVENUECAT_CONTRIBUTION_LARGE_PRODUCT_ID',
    defaultValue: 'streambeat_support_large',
  );

  static const admobAndroidBannerId = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER_ID',
  );
  static const admobIosBannerId = String.fromEnvironment('ADMOB_IOS_BANNER_ID');

  static bool get supportsNativeMonetization =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String get revenueCatApiKey {
    if (!supportsNativeMonetization) return '';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => revenueCatAndroidApiKey,
      TargetPlatform.iOS => revenueCatIosApiKey,
      _ => '',
    };
  }

  static String get admobBannerId {
    if (!supportsNativeMonetization) return '';
    if (kDebugMode) {
      return switch (defaultTargetPlatform) {
        TargetPlatform.android => 'ca-app-pub-3940256099942544/9214589741',
        TargetPlatform.iOS => 'ca-app-pub-3940256099942544/2435281174',
        _ => '',
      };
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => admobAndroidBannerId,
      TargetPlatform.iOS => admobIosBannerId,
      _ => '',
    };
  }
}
