import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/monetization_config.dart';

void main() {
  Map<String, Object?> configuration() => {
    'REVENUECAT_ANDROID_API_KEY': 'goog_UnitTestOnly',
    'REVENUECAT_IOS_API_KEY': 'appl_UnitTestOnly',
    'REVENUECAT_ENTITLEMENT_ID': 'remove_ads',
    'REVENUECAT_MONTHLY_PRODUCT_ID': 'remove_ads_monthly',
    'REVENUECAT_OFFERING_ID': 'support',
    'REVENUECAT_CONTRIBUTION_SMALL_PRODUCT_ID': 'streambeat_support_small',
    'REVENUECAT_CONTRIBUTION_MEDIUM_PRODUCT_ID': 'streambeat_support_medium',
    'REVENUECAT_CONTRIBUTION_LARGE_PRODUCT_ID': 'streambeat_support_large',
    'ADMOB_ANDROID_BANNER_ID': 'ca-app-pub-1234567890123456/1234567890',
    'ADMOB_IOS_BANNER_ID': 'ca-app-pub-1234567890123456/2345678901',
  };
  Map<String, Object?> plist() => {
    'GADApplicationIdentifier': 'ca-app-pub-1234567890123456~3456789012',
    'NSLocationWhenInUseUsageDescription':
        'StreamBeat usa tu ubicación para sugerirte emisoras de tu país.',
    'NSLocationAlwaysAndWhenInUseUsageDescription':
        'StreamBeat usa tu ubicación para mostrar emisoras cercanas.',
    'CFBundleURLTypes': [
      {
        'CFBundleURLSchemes': [
          'com.victorflores.streambeat',
          'com.googleusercontent.apps.123456789012-iosclient',
        ],
      },
    ],
  };

  test(
    'monetization works without backend or authentication configuration',
    () {
      final config = configuration()
        ..removeWhere(
          (key, _) =>
              key.startsWith('SUPABASE_') ||
              key.startsWith('GOOGLE_') ||
              key == 'AUTH_CALLBACK_URL',
        );
      expect(
        validateMonetizationConfig(
          config,
          platform: MonetizationPlatform.android,
        ),
        isEmpty,
      );
      expect(
        validateMonetizationConfig(
          config,
          platform: MonetizationPlatform.ios,
          iosPlist: plist(),
        ),
        isEmpty,
      );
    },
  );

  test('Android checks do not require iOS keys', () {
    final config = configuration()
      ..remove('REVENUECAT_IOS_API_KEY')
      ..remove('ADMOB_IOS_BANNER_ID');
    expect(
      validateMonetizationConfig(
        config,
        platform: MonetizationPlatform.android,
      ),
      isEmpty,
    );
  });

  test('iOS checks native identifiers and its own public keys', () {
    expect(
      validateMonetizationConfig(
        configuration(),
        platform: MonetizationPlatform.ios,
        iosPlist: plist(),
      ),
      isEmpty,
    );
  });

  test('iOS rejects missing keys, wrong store keys and sample ad app', () {
    final config = configuration()
      ..['REVENUECAT_IOS_API_KEY'] = 'goog_WrongStore'
      ..['ADMOB_IOS_BANNER_ID'] = '';
    final native = plist()
      ..['GADApplicationIdentifier'] = 'ca-app-pub-3940256099942544~1458002511';
    final errors = validateMonetizationConfig(
      config,
      platform: MonetizationPlatform.ios,
      iosPlist: native,
    ).join('\n');
    expect(errors, contains('REVENUECAT_IOS_API_KEY'));
    expect(errors, contains('ADMOB_IOS_BANNER_ID'));
    expect(errors, contains('GADApplicationIdentifier'));
  });

  test('iOS rejects mismatched AdMob publisher', () {
    final native = plist()
      ..['CFBundleURLTypes'] = []
      ..['GADApplicationIdentifier'] = 'ca-app-pub-9876543210987654~3456789012';
    final errors = validateMonetizationConfig(
      configuration(),
      platform: MonetizationPlatform.ios,
      iosPlist: native,
    ).join('\n');
    expect(errors, contains('editores diferentes'));
  });

  test('iOS requires both location privacy purpose strings', () {
    final native = plist()
      ..remove('NSLocationWhenInUseUsageDescription')
      ..['NSLocationAlwaysAndWhenInUseUsageDescription'] = '   ';
    final errors = validateMonetizationConfig(
      configuration(),
      platform: MonetizationPlatform.ios,
      iosPlist: native,
    ).join('\n');
    expect(errors, contains('NSLocationWhenInUseUsageDescription'));
    expect(errors, contains('NSLocationAlwaysAndWhenInUseUsageDescription'));
  });

  test('placeholder and non-string values fail without casting errors', () {
    final config = configuration()
      ..['REVENUECAT_ANDROID_API_KEY'] = 'goog_YOUR_PUBLIC_SDK_KEY'
      ..['REVENUECAT_IOS_API_KEY'] = 123;
    expect(
      validateMonetizationConfig(
        config,
        platform: MonetizationPlatform.android,
      ),
      isNotEmpty,
    );
  });

  for (final tier in ['SMALL', 'MEDIUM', 'LARGE']) {
    test('$tier contribution product configuration remains required', () {
      final key = 'REVENUECAT_CONTRIBUTION_${tier}_PRODUCT_ID';
      final config = configuration()..remove(key);
      final errors = validateMonetizationConfig(
        config,
        platform: MonetizationPlatform.android,
      ).join('\n');
      expect(errors, contains(key));
      config[key] = 'wrong_product';
      expect(
        validateMonetizationConfig(
          config,
          platform: MonetizationPlatform.android,
        ),
        isNotEmpty,
      );
    });
  }

  test('administrative secrets cannot be bundled in the client', () {
    final config = configuration()
      ..['SUPABASE_SERVICE_ROLE_KEY'] = 'never-print-this';
    final errors = validateMonetizationConfig(
      config,
      platform: MonetizationPlatform.android,
    ).join('\n');
    expect(errors, contains('SUPABASE_SERVICE_ROLE_KEY'));
    expect(errors, isNot(contains('never-print-this')));
  });
}
