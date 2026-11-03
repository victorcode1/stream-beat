import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// External tips never grant the store's ad-removal entitlement.
class ExternalSupportSection extends StatelessWidget {
  const ExternalSupportSection({required this.onOpen, super.key});

  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    // Store builds must not link to external tips: Google Play only exempts
    // tips where 100% reaches the creator, and PayPal keeps a fee. Apple
    // needs a separate storefront/entitlement implementation.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 28),
        Text(
          LocaleKeys.external_support_title.tr(),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Text(
          LocaleKeys.external_support_disclosure.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('external-support'),
          onPressed: onOpen,
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(LocaleKeys.external_support_action.tr()),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
