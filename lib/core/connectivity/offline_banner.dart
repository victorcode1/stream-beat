import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/connectivity/internet_status_provider.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:internet_connection_monitor/internet_connection_monitor.dart';

/// Aviso «Sin Internet» sobre el contenido.
///
/// Solo aparece cuando el monitor confirma que no hay conexion, y desaparece
/// solo cuando vuelve. «Reintentar» pide una revision inmediata.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(internetStatusProvider).value;
    final isOffline = status == InternetStatus.offline;

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: isOffline
          ? OfflineBannerContent(
              onRetry: () =>
                  unawaited(ref.read(internetMonitorProvider).check()),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

/// Contenido visual del aviso, separado para probarlo sin red real.
class OfflineBannerContent extends StatelessWidget {
  const OfflineBannerContent({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Material(
        key: const Key('offline-banner'),
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          child: Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: colors.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  LocaleKeys.no_internet.tr(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: colors.onErrorContainer,
                ),
                child: Text(LocaleKeys.retry.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
