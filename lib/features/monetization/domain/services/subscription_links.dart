import 'package:flow_music/features/monetization/domain/entities/subscription_access.dart';

/// Never infer the billing store from the device: an account can have a
/// subscription purchased on a different platform.
abstract final class SubscriptionLinks {
  static final support = Uri.parse('https://ko-fi.com/streambeat');

  static final privacy = Uri.parse(
    'https://victorcode1.github.io/flow-music/privacy/',
  );
  static final appleTerms = Uri.parse(
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
  );

  static Uri? management(SubscriptionAccess? access) {
    if (access == null) return null;
    final supplied = Uri.tryParse(access.managementUrl ?? '');
    if (supplied != null &&
        supplied.scheme == 'https' &&
        supplied.userInfo.isEmpty &&
        (!supplied.hasPort || supplied.port == 443) &&
        ((supplied.host == 'apps.apple.com' &&
                supplied.path == '/account/subscriptions') ||
            (supplied.host == 'play.google.com' &&
                supplied.path == '/store/account/subscriptions'))) {
      return supplied;
    }
    return switch (access.store) {
      'appStore' || 'macAppStore' => Uri.parse(
        'https://apps.apple.com/account/subscriptions',
      ),
      'playStore' => Uri.parse(
        'https://play.google.com/store/account/subscriptions',
      ),
      _ => null,
    };
  }
}
