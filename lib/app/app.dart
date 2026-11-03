import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/app/main_app_controller.dart';
import 'package:flow_music/core/routes/routes.dart';
import 'package:flow_music/core/theme/custom_theme.dart';
import 'package:flow_music/core/utils/main_controller.dart';
import 'package:flow_music/features/settings/presentation/controllers/accent_color_controller.dart';
import 'package:flow_music/features/settings/presentation/controllers/theme_mode_controller.dart';
import 'package:flow_music/features/account/presentation/providers/local_user_data_providers.dart';
import 'package:flow_music/features/settings/data/settings_local_data_source.dart';
import 'package:flow_music/features/daily_recommendations/presentation/widgets/daily_recommendation_listener.dart';
import 'package:flow_music/features/monetization/presentation/widgets/subscription_promo_listener.dart';
import 'package:flow_music/shared/widgets/flow_ambient_background.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> with WidgetsBindingObserver {
  late final MainAppController _appController;
  int _lastAppliedLocalRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appController = ref.read(mainAppControllerProvider);
    _appController.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_appController.refreshPurchases());
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(mainController);
    final router = ref.read(routeProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    final accent = ref.watch(accentColorControllerProvider);
    final localRevision = ref.watch(localUserDataRevisionProvider);
    if (localRevision != _lastAppliedLocalRevision) {
      _lastAppliedLocalRevision = localRevision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyLocalLocale();
      });
    }

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: CustomTheme.light(accent.color),
      darkTheme: CustomTheme.dark(accent.color),
      themeMode: themeMode,
      builder: (context, child) {
        return SubscriptionPromoListener(
          child: DailyRecommendationListener(
            child: FlowAmbientBackground(
              child: ScaffoldMessenger(
                key: controller.scaffoldMessage,
                child: child ?? const SizedBox(),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _applyLocalLocale() async {
    final tag = const SettingsLocalDataSource().read().locale;
    final requested = tag == null || tag.isEmpty
        ? WidgetsBinding.instance.platformDispatcher.locale
        : _localeFromTag(tag);
    final supported = context.supportedLocales.where(
      (locale) => locale.languageCode == requested.languageCode,
    );
    final locale = supported.firstWhere(
      (candidate) => candidate.countryCode == requested.countryCode,
      orElse: () => supported.isEmpty
          ? context.fallbackLocale ?? const Locale('en')
          : supported.first,
    );
    if (context.locale != locale) await context.setLocale(locale);
  }

  Locale _localeFromTag(String tag) {
    final parts = tag.split(RegExp('[-_]'));
    return parts.length > 1
        ? Locale(parts.first, parts[1])
        : Locale(parts.first);
  }
}
