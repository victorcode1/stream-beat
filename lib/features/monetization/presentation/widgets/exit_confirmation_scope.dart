import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/audio/audio_playing_provider.dart';
import 'package:flow_music/core/config/app_environment.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/monetization/domain/services/ad_visibility_policy.dart';
import 'package:flow_music/features/monetization/presentation/controllers/exit_ad_controller.dart';
import 'package:flow_music/features/monetization/presentation/providers/ad_providers.dart';
import 'package:flow_music/features/monetization/presentation/providers/monetization_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Asks for confirmation when Android's Back would close the app, showing a
/// preloaded 300x250 ad above the buttons.
///
/// It only intercepts Back for users who see ads, have given ad consent and
/// are not listening: closing the app while the radio plays keeps it playing
/// in the background, so that flow is never interrupted.
class ExitConfirmationScope extends ConsumerStatefulWidget {
  const ExitConfirmationScope({
    required this.child,
    this.enabled = true,
    this.onExit = _closeApp,
    super.key,
  });

  final Widget child;

  /// False while the screen handles Back itself (for example, open search).
  final bool enabled;
  final Future<void> Function() onExit;

  static Future<void> _closeApp() => SystemNavigator.pop();

  @override
  ConsumerState<ExitConfirmationScope> createState() =>
      _ExitConfirmationScopeState();
}

class _ExitConfirmationScopeState extends ConsumerState<ExitConfirmationScope> {
  bool _dialogOpen = false;

  bool get _platformSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool _shouldIntercept() {
    if (!widget.enabled || !_platformSupported) return false;
    final access = ref.watch(subscriptionAccessProvider).value;
    final consent = ref.watch(canRequestAdsProvider).value;
    final playing = ref.watch(audioPlayingProvider).value ?? false;
    return access != null &&
        consent == true &&
        !playing &&
        AdVisibilityPolicy.shouldShow(
          access: access,
          adsSupported: AppEnvironment.supportsNativeMonetization,
        );
  }

  @override
  Widget build(BuildContext context) {
    final intercept = _shouldIntercept();
    if (intercept) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(exitAdControllerProvider).preload();
      });
    }
    return PopScope(
      canPop: !intercept,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !intercept || _dialogOpen) return;
        unawaited(_confirmExit());
      },
      child: widget.child,
    );
  }

  Future<void> _confirmExit() async {
    _dialogOpen = true;
    final controller = ref.read(exitAdControllerProvider);
    final ad = controller.takeLoaded();
    try {
      final exit = await showDialog<bool>(
        context: context,
        builder: (_) => ExitConfirmationDialog(ad: ad),
      );
      if (exit == true) await widget.onExit();
    } finally {
      _dialogOpen = false;
      unawaited(ad?.dispose());
      if (mounted) controller.preload();
    }
  }
}

class ExitConfirmationDialog extends StatelessWidget {
  const ExitConfirmationDialog({this.ad, super.key});

  /// A loaded ad, or null to show the dialog without one.
  final BannerAd? ad;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ad = this.ad;
    final adSize = AdSize.mediumRectangle;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      // Phone-sized on tablets too: the ad and buttons stay grouped.
      constraints: const BoxConstraints(maxWidth: 400),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fitsAd =
                ad != null && constraints.maxWidth >= adSize.width.toDouble();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  LocaleKeys.exit_dialog_title.tr(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (fitsAd) ...[
                  const SizedBox(height: 16),
                  Text(
                    LocaleKeys.exit_dialog_ad_label.tr(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: SizedBox(
                      key: const Key('exit-ad'),
                      width: adSize.width.toDouble(),
                      height: adSize.height.toDouble(),
                      child: AdWidget(ad: ad),
                    ),
                  ),
                  // AdMob asks to keep ads clear of exit-confirmation buttons.
                  const SizedBox(height: 32),
                ] else
                  const SizedBox(height: 20),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 8,
                  overflowSpacing: 8,
                  overflowAlignment: OverflowBarAlignment.end,
                  children: [
                    TextButton(
                      key: const Key('exit-cancel'),
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(LocaleKeys.exit_dialog_cancel.tr()),
                    ),
                    FilledButton(
                      key: const Key('exit-confirm'),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(LocaleKeys.exit_dialog_confirm.tr()),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
