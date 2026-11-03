import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/account/presentation/widgets/local_library_tools.dart';
import 'package:flow_music/features/monetization/domain/services/subscription_links.dart';
import 'package:flow_music/features/monetization/presentation/widgets/subscription_legal_footer.dart';
import 'package:flow_music/features/monetization/presentation/widgets/external_support_section.dart';
import 'package:flow_music/features/monetization/domain/entities/subscription_access.dart';
import 'package:flow_music/features/monetization/domain/repositories/subscription_repository.dart';
import 'package:flow_music/features/monetization/presentation/providers/ad_providers.dart';
import 'package:flow_music/features/monetization/presentation/providers/monetization_providers.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class MonetizationSettingsCard extends ConsumerStatefulWidget {
  const MonetizationSettingsCard({super.key});

  @override
  ConsumerState<MonetizationSettingsCard> createState() =>
      _MonetizationSettingsCardState();
}

class _MonetizationSettingsCardState
    extends ConsumerState<MonetizationSettingsCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final access = ref.watch(subscriptionAccessProvider).value;
    final offersState = ref.watch(premiumOffersProvider);
    final offers = offersState.value ?? const <PremiumOffer>[];
    final active = access?.isActive ?? false;
    final monthlyActive = access?.hasMonthlySubscription ?? false;
    final managementUrl = SubscriptionLinks.management(access);
    final serviceAvailable = access?.serviceAvailable ?? false;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary.withValues(alpha: 0.2),
            colors.surfaceContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: active ? colors.primary : colors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  active ? Icons.verified_rounded : Icons.hide_source_rounded,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active
                          ? LocaleKeys.premium_active_title.tr()
                          : LocaleKeys.remove_ads_title.tr(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      active
                          ? LocaleKeys.premium_active_subtitle.tr()
                          : LocaleKeys.remove_ads_subtitle.tr(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (active)
                Chip(
                  avatar: const Icon(Icons.check_rounded, size: 17),
                  label: Text(LocaleKeys.premium_badge.tr()),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!serviceAvailable) ...[
            Text(
              LocaleKeys.monetization_unavailable.tr(),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ] else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!active && offersState.isLoading)
                  const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (!active)
                  for (final offer in offers)
                    FilledButton.icon(
                      key: ValueKey('contribution-${offer.kind.name}'),
                      onPressed: _busy ? null : () => _purchase(offer.kind),
                      icon: const Icon(Icons.favorite_outline_rounded),
                      label: Text(
                        'contribution_action'.tr(
                          namedArgs: {'price': offer.priceLabel},
                        ),
                      ),
                    ),
                if (!active &&
                    !offersState.isLoading &&
                    (offersState.hasError ||
                        offers.length < PremiumOfferKind.values.length))
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () => ref.invalidate(premiumOffersProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(LocaleKeys.retry.tr()),
                  ),
                OutlinedButton(
                  onPressed: _busy ? null : _restore,
                  child: Text(LocaleKeys.restore_purchase.tr()),
                ),
              ],
            ),
          const SizedBox(height: 8),
          ExternalSupportSection(
            onOpen: _busy ? null : () => _openLink(SubscriptionLinks.support),
          ),
          const LocalLibraryTools(),
          if (monthlyActive && managementUrl != null)
            TextButton.icon(
              onPressed: _busy ? null : () => _openLink(managementUrl),
              icon: const Icon(Icons.manage_accounts_outlined),
              label: Text(LocaleKeys.subscription_manage.tr()),
            ),
          SubscriptionLegalFooter(onOpenLink: _openLink),
          const _PrivacyOptionsButton(),
        ],
      ),
    );
  }

  Future<void> _openLink(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _showMessage(LocaleKeys.subscription_link_failed.tr());
      }
    } catch (_) {
      if (mounted) _showMessage(LocaleKeys.subscription_link_failed.tr());
    }
  }

  Future<void> _purchase(PremiumOfferKind kind) async {
    setState(() => _busy = true);
    try {
      await ref.read(subscriptionActionsProvider).purchase(kind);
      if (mounted) _showMessage(LocaleKeys.subscription_success.tr());
    } on SubscriptionFailure catch (error) {
      if (mounted && !error.cancelled) {
        _showMessage(error.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      final access = await ref.read(subscriptionActionsProvider).restore();
      if (mounted) {
        _showMessage(
          access.isActive
              ? LocaleKeys.restore_success.tr()
              : LocaleKeys.restore_empty.tr(),
        );
      }
    } on SubscriptionFailure catch (error) {
      if (mounted && !error.cancelled) {
        _showMessage(error.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PrivacyOptionsButton extends ConsumerWidget {
  const _PrivacyOptionsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final required = ref.watch(privacyOptionsRequiredProvider).value;
    if (required != true) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextButton.icon(
        onPressed: () =>
            ref.read(adConsentRepositoryProvider).showPrivacyOptions(),
        icon: const Icon(Icons.privacy_tip_outlined),
        label: Text(LocaleKeys.ad_privacy_options.tr()),
      ),
    );
  }
}
