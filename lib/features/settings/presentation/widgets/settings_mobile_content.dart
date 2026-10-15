import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/daily_recommendations/domain/repositories/daily_recommendation_repository.dart';
import 'package:flow_music/features/daily_recommendations/presentation/providers/daily_recommendation_providers.dart';
import 'package:flow_music/features/monetization/presentation/widgets/monetization_settings_card.dart';
import 'package:flow_music/features/settings/presentation/controllers/accent_color_controller.dart';
import 'package:flow_music/features/settings/presentation/controllers/autoplay_enabled_controller.dart';
import 'package:flow_music/features/settings/presentation/controllers/settings_page_controller.dart';
import 'package:flow_music/features/settings/presentation/controllers/theme_mode_controller.dart';
import 'package:flow_music/features/settings/presentation/pages/station_rights_page.dart';
import 'package:flow_music/features/settings/presentation/widgets/accent_color_palette.dart';
import 'package:flow_music/features/settings/presentation/widgets/developer_contact_card.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SettingsMobileContent extends ConsumerWidget {
  const SettingsMobileContent({
    super.key,
    required this.onBack,
    required this.pageController,
  });

  final VoidCallback onBack;
  final SettingsPageController pageController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeControllerProvider);
    final themeModeController = ref.read(themeModeControllerProvider.notifier);
    final accent = ref.watch(accentColorControllerProvider);
    final accentController = ref.read(accentColorControllerProvider.notifier);
    final autoplayEnabled = ref.watch(autoplayEnabledControllerProvider);
    final autoplayController = ref.read(
      autoplayEnabledControllerProvider.notifier,
    );
    final dailyRecommendations = ref.watch(
      dailyRecommendationControllerProvider,
    );
    final dailyRecommendationController = ref.read(
      dailyRecommendationControllerProvider.notifier,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: onBack,
        ),
        title: Text(LocaleKeys.settings.tr()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const MonetizationSettingsCard(),
          const SizedBox(height: 16),
          // Tarjeta "Tema y apariencia": selector de tema + acento de marca.
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardHeader(
                  icon: Icons.wb_sunny_rounded,
                  title: LocaleKeys.theme_and_appearance.tr(),
                ),
                const SizedBox(height: 18),
                _ThemeModeSelector(
                  current: themeMode,
                  onSelected: themeModeController.setMode,
                ),
                const SizedBox(height: 18),
                AccentColorPalette(
                  current: accent,
                  onSelected: accentController.setAccent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Tarjeta de preferencias: idioma + toggles.
          _SettingsCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.language_rounded,
                  title: LocaleKeys.language.tr(),
                  subtitle: pageController.languageName(context.locale),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onTap: () => _showLanguagePicker(context, ref),
                ),
                const _RowDivider(),
                _SettingsRow(
                  icon: Icons.music_note_rounded,
                  title: LocaleKeys.continuous_playback.tr(),
                  trailing: Switch.adaptive(
                    value: autoplayEnabled,
                    onChanged: autoplayController.setEnabled,
                  ),
                ),
                if (dailyRecommendationController.isSupported) ...[
                  const _RowDivider(),
                  _SettingsRow(
                    icon: Icons.notifications_active_rounded,
                    title: LocaleKeys.daily_radio_recommendations.tr(),
                    subtitle: LocaleKeys.daily_radio_recommendations_subtitle
                        .tr(),
                    trailing: Switch.adaptive(
                      value: dailyRecommendations,
                      onChanged: (enabled) => _setDailyRecommendations(
                        context,
                        dailyRecommendationController,
                        enabled,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const StationRightsEntry(),
          const SizedBox(height: 14),
          const DeveloperContactCard(),
        ],
      ),
    );
  }

  Future<void> _setDailyRecommendations(
    BuildContext context,
    DailyRecommendationController controller,
    bool enabled,
  ) async {
    final result = await controller.setEnabled(
      enabled,
      languageCode: context.locale.languageCode,
    );
    if (!context.mounted) return;
    final message = switch (result) {
      DailyRecommendationToggleResult.enabled =>
        LocaleKeys.daily_radio_recommendations_enabled.tr(),
      DailyRecommendationToggleResult.permissionDenied =>
        LocaleKeys.daily_radio_permission_denied.tr(),
      DailyRecommendationToggleResult.failed =>
        LocaleKeys.daily_radio_schedule_failed.tr(),
      DailyRecommendationToggleResult.unavailable =>
        LocaleKeys.daily_radio_unavailable.tr(),
      DailyRecommendationToggleResult.disabled => null,
    };
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showLanguagePicker(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  LocaleKeys.language.tr(),
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              for (final locale in const [
                Locale('es'),
                Locale('en'),
                Locale('pt', 'BR'),
              ])
                ListTile(
                  title: Text(pageController.languageName(locale)),
                  trailing: context.locale == locale
                      ? Icon(
                          Icons.check_rounded,
                          color: Theme.of(sheetContext).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    pageController.persistLocale(context, ref, locale);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

/// Contenedor con el aspecto de tarjeta del diseno StreamBeat.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      children: [
        _IconBadge(icon: icon),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Cuadro redondeado con tinte de acento para los iconos de cada fila.
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: colors.primary),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            _IconBadge(icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 66,
      endIndent: 12,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.6),
    );
  }
}

/// Selector de tema con vista previa: Sistema / Claro / Oscuro.
class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({required this.current, required this.onSelected});

  final ThemeMode current;
  final ValueChanged<ThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = <(ThemeMode, String)>[
      (ThemeMode.system, LocaleKeys.theme_mode_system.tr()),
      (ThemeMode.light, LocaleKeys.theme_mode_light.tr()),
      (ThemeMode.dark, LocaleKeys.theme_mode_dark.tr()),
    ];
    return Row(
      children: [
        for (final (index, option) in options.indexed) ...[
          if (index > 0) const SizedBox(width: 12),
          Expanded(
            child: _ThemeModeOption(
              mode: option.$1,
              label: option.$2,
              selected: current == option.$1,
              onTap: () => onSelected(option.$1),
            ),
          ),
        ],
      ],
    );
  }
}

class _ThemeModeOption extends StatelessWidget {
  const _ThemeModeOption({
    required this.mode,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                _ThemePreview(mode: mode),
                if (selected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: colors.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mini lienzo que representa cada tema (claro / oscuro / mitad y mitad).
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.mode});

  final ThemeMode mode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const light = Color(0xFFF1F1F3);
    const dark = Color(0xFF101010);

    final Decoration decoration = switch (mode) {
      ThemeMode.light => const BoxDecoration(color: light),
      ThemeMode.dark => const BoxDecoration(color: dark),
      ThemeMode.system => const BoxDecoration(
        gradient: LinearGradient(
          colors: [light, light, dark, dark],
          stops: [0.0, 0.5, 0.5, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    };

    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(decoration: decoration),
    );
  }
}
