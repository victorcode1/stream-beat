import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/monetization/presentation/widgets/monetization_settings_card.dart';
import 'package:flow_music/features/settings/presentation/controllers/accent_color_controller.dart';
import 'package:flow_music/features/settings/presentation/controllers/autoplay_enabled_controller.dart';
import 'package:flow_music/features/settings/presentation/controllers/settings_page_controller.dart';
import 'package:flow_music/features/settings/presentation/controllers/theme_mode_controller.dart';
import 'package:flow_music/features/settings/presentation/pages/station_rights_page.dart';
import 'package:flow_music/features/settings/presentation/widgets/accent_color_palette.dart';
import 'package:flow_music/features/settings/presentation/widgets/developer_contact_card.dart';
import 'package:flow_music/features/settings/presentation/widgets/settings_web_card.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SettingsDesktopContent extends ConsumerWidget {
  const SettingsDesktopContent({
    super.key,
    required this.embedded,
    required this.onBack,
    required this.pageController,
  });

  final bool embedded;
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

    final content = SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!embedded) ...[
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: onBack,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        LocaleKeys.settings.tr(),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                ],
                Expanded(
                  child: ListView(
                    children: [
                      const MonetizationSettingsCard(),
                      const SizedBox(height: 14),
                      SettingsWebCard(
                        icon: Icons.language_rounded,
                        title: LocaleKeys.language.tr(),
                        subtitle:
                            '${LocaleKeys.current_language.tr()}: ${pageController.languageName(context.locale)}',
                        trailing: DropdownButton<Locale>(
                          value: context.locale,
                          onChanged: (Locale? newValue) {
                            if (newValue != null) {
                              pageController.persistLocale(
                                context,
                                ref,
                                newValue,
                              );
                            }
                          },
                          items: [
                            DropdownMenuItem(
                              value: Locale('en'),
                              child: Text(LocaleKeys.english.tr()),
                            ),
                            DropdownMenuItem(
                              value: Locale('es'),
                              child: Text(LocaleKeys.spanish.tr()),
                            ),
                            DropdownMenuItem(
                              value: Locale('pt', 'BR'),
                              child: Text(LocaleKeys.portuguese_brazil.tr()),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SettingsWebCard(
                        icon: Icons.queue_music_rounded,
                        title: LocaleKeys.autoplay_queue.tr(),
                        subtitle: LocaleKeys.autoplay_queue_subtitle.tr(),
                        trailing: Switch.adaptive(
                          value: autoplayEnabled,
                          onChanged: autoplayController.setEnabled,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SettingsWebCard(
                        icon: pageController.themeModeIcon(themeMode),
                        title: LocaleKeys.theme_mode.tr(),
                        subtitle:
                            '${LocaleKeys.current_theme_mode.tr()}: ${pageController.themeModeLabel(themeMode)}',
                        trailing: DropdownButton<ThemeMode>(
                          value: themeMode,
                          onChanged: (ThemeMode? newValue) {
                            if (newValue != null) {
                              themeModeController.setMode(newValue);
                            }
                          },
                          items: [
                            DropdownMenuItem(
                              value: ThemeMode.system,
                              child: Text(LocaleKeys.theme_mode_system.tr()),
                            ),
                            DropdownMenuItem(
                              value: ThemeMode.light,
                              child: Text(LocaleKeys.theme_mode_light.tr()),
                            ),
                            DropdownMenuItem(
                              value: ThemeMode.dark,
                              child: Text(LocaleKeys.theme_mode_dark.tr()),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SettingsWebCard(
                        icon: Icons.palette_rounded,
                        title: LocaleKeys.accent_color.tr(),
                        subtitle: LocaleKeys.theme_and_appearance.tr(),
                        trailing: SizedBox(
                          width: 340,
                          child: AccentColorPalette(
                            current: accent,
                            onSelected: accentController.setAccent,
                            minSwatchSize: 44,
                            maxSwatchSize: 48,
                            spacing: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const StationRightsEntry(),
                      const SizedBox(height: 14),
                      const DeveloperContactCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (embedded) {
      return ColoredBox(color: Colors.transparent, child: content);
    }

    return Scaffold(backgroundColor: Colors.transparent, body: content);
  }
}
