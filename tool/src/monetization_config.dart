enum MonetizationPlatform { android, ios }

/// Local checks do not prove store approval, pricing or sandbox purchases.
List<String> validateMonetizationConfig(
  Map<String, Object?> config, {
  required MonetizationPlatform platform,
  Map<String, Object?>? iosPlist,
}) {
  final errors = <String>[];
  final isIos = platform == MonetizationPlatform.ios;
  final suffix = isIos ? 'IOS' : 'ANDROID';
  final revenueKey = 'REVENUECAT_${suffix}_API_KEY';
  final bannerKey = 'ADMOB_${suffix}_BANNER_ID';
  final required = [
    revenueKey,
    'REVENUECAT_ENTITLEMENT_ID',
    'REVENUECAT_MONTHLY_PRODUCT_ID',
    'REVENUECAT_OFFERING_ID',
    'REVENUECAT_CONTRIBUTION_SMALL_PRODUCT_ID',
    'REVENUECAT_CONTRIBUTION_MEDIUM_PRODUCT_ID',
    'REVENUECAT_CONTRIBUTION_LARGE_PRODUCT_ID',
    bannerKey,
  ];
  String value(String key) =>
      config[key] is String ? (config[key] as String).trim() : '';
  for (final key in required) {
    final text = value(key);
    if (text.isEmpty ||
        RegExp(r'YOUR_|example|0{10}', caseSensitive: false).hasMatch(text)) {
      errors.add('$key falta o contiene un valor de ejemplo.');
    }
  }
  for (final key in config.keys) {
    if (RegExp(
      r'SERVICE_ROLE|SECRET|PRIVATE_KEY|PASSWORD',
      caseSensitive: false,
    ).hasMatch(key)) {
      errors.add('$key no puede incluirse en la configuración del cliente.');
    }
  }
  final prefix = isIos ? 'appl_' : 'goog_';
  if (!RegExp('^$prefix[A-Za-z0-9]+\$').hasMatch(value(revenueKey))) {
    errors.add('$revenueKey debe ser una clave pública $prefix*.');
  }
  bool productionAdId(String id, String separator) =>
      RegExp('^ca-app-pub-[0-9]{16}$separator[0-9]{10}\$').hasMatch(id) &&
      !id.contains('3940256099942544') &&
      !id.contains('0000000000000000');
  if (!productionAdId(value(bannerKey), '/')) {
    errors.add('$bannerKey no es una unidad de producción válida.');
  }
  final expectedProducts = {
    'REVENUECAT_ENTITLEMENT_ID': 'remove_ads',
    'REVENUECAT_MONTHLY_PRODUCT_ID': 'remove_ads_monthly',
    'REVENUECAT_OFFERING_ID': 'support',
    'REVENUECAT_CONTRIBUTION_SMALL_PRODUCT_ID': 'streambeat_support_small',
    'REVENUECAT_CONTRIBUTION_MEDIUM_PRODUCT_ID': 'streambeat_support_medium',
    'REVENUECAT_CONTRIBUTION_LARGE_PRODUCT_ID': 'streambeat_support_large',
  };
  for (final entry in expectedProducts.entries) {
    if (value(entry.key) != entry.value) {
      errors.add('${entry.key} debe ser ${entry.value}.');
    }
  }
  if (isIos) {
    for (final key in [
      'NSLocationWhenInUseUsageDescription',
      'NSLocationAlwaysAndWhenInUseUsageDescription',
    ]) {
      final purpose = iosPlist?[key];
      if (purpose is! String || purpose.trim().isEmpty) {
        errors.add('Info.plist: falta una descripción válida para $key.');
      }
    }
    final appId = iosPlist?['GADApplicationIdentifier'];
    if (appId is! String || !productionAdId(appId, '~')) {
      errors.add(
        'Info.plist: GADApplicationIdentifier sigue vacío o es de prueba.',
      );
    } else if (value(bannerKey).split('/').first != appId.split('~').first) {
      errors.add(
        'La app de AdMob y el banner iOS pertenecen a editores diferentes.',
      );
    }
  }
  return errors;
}
