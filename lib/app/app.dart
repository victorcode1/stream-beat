import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/app/main_app_controller.dart';
import 'package:flow_music/core/routes/routes.dart';
import 'package:flow_music/core/theme/custom_theme.dart';
import 'package:flow_music/core/utils/main_controller.dart';
import 'package:flow_music/features/autoplay/presentation/controllers/cache_status_controller.dart';
import 'package:flow_music/features/settings/presentation/controllers/accent_color_controller.dart';
import 'package:flow_music/features/settings/presentation/controllers/visual_style_controller.dart';
import 'package:flow_music/features/settings/presentation/controllers/theme_mode_controller.dart';
import 'package:flow_music/features/account/presentation/widgets/account_recovery_listener.dart';
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

  @override
  void initState() {
    super.initState();
    _appController = ref.read(mainAppControllerProvider);
    WidgetsBinding.instance.addObserver(this);
    _appController.initialize();
  }

  @override
  void dispose() {
    _appController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appController.handleAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(mainController);
    final router = ref.read(routeProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    final accent = ref.watch(accentColorControllerProvider);
    final style = ref.watch(visualStyleControllerProvider);

    ref.listen<CacheStatus>(
      cacheStatusControllerProvider,
      _appController.handleCacheStatusChanged,
    );
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: CustomTheme.light(accent.color, style),
      darkTheme: CustomTheme.dark(accent.color, style),
      // Mola y Carteles son mundos oscuros: no cambian con la apariencia.
      themeMode: style.alwaysDark ? ThemeMode.dark : themeMode,
      builder: (context, child) {
        return AccountRecoveryListener(
          child: FlowAmbientBackground(
            child: ScaffoldMessenger(
              key: controller.scaffoldMessage,
              child: child ?? const SizedBox(),
            ),
          ),
        );
      },
    );
  }
}
