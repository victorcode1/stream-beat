import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/app/app.dart';
import 'package:flow_music/core/analytics/product_analytics.dart';
import 'package:flow_music/core/audio/background_audio_handler.dart';
import 'package:flow_music/core/backend/backend_bootstrap.dart';
import 'package:flow_music/core/backend/backend_providers.dart';
import 'package:flow_music/core/engagement/review_prompt_coordinator.dart';
import 'package:flow_music/core/monitoring/sentry_config.dart';
import 'package:flow_music/features/flow_mix/data/flow_mix_feedback_repository.dart';
import 'package:flow_music/features/history/data/playback_history_repository.dart';
import 'package:flow_music/features/radio/data/radio_favorites_repository.dart';
import 'package:flow_music/features/radio/data/radio_playlists_repository.dart';
import 'package:flow_music/features/radio/data/radio_station_health_repository.dart';
import 'package:flow_music/features/radio/data/station_removals_repository.dart';
import 'package:flow_music/features/settings/data/settings_storage.dart';
import 'package:flow_music/shared/custom_info_version/provider/info_version.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<void> main() {
  return SentryConfig.initialize(appRunner: _bootstrap);
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await initializeDateFormatting();
  await Hive.initFlutter();
  await Hive.openBox(settingsBoxName);
  unawaited(StationRemovalsRepository.instance.load());
  await Hive.openBox(playbackHistoryBoxName);
  await Hive.openBox(flowMixFeedbackBoxName);
  await Hive.openBox(radioFavoritesBoxName);
  await Hive.openBox(radioPlaylistsBoxName);
  await Hive.openBox(radioStationHealthBoxName);
  await initFlowAudioHandler();
  final backend = await BackendBootstrap.initialize();
  final packageInfo = await PackageInfo.fromPlatform();
  final settingsBox = Hive.box(settingsBoxName);
  final productAnalytics = ProductAnalytics.create(
    client: backend.supabaseClient,
    settingsBox: settingsBox,
    version: packageInfo.version,
    buildNumber: packageInfo.buildNumber,
  );
  final reviewPromptCoordinator = ReviewPromptCoordinator(
    store: HiveEngagementStore(settingsBox),
    gateway: InAppReviewGateway(),
    analytics: productAnalytics,
  );

  runApp(
    ProviderScope(
      overrides: [
        supabaseClientProvider.overrideWithValue(backend.supabaseClient),
        productAnalyticsProvider.overrideWithValue(productAnalytics),
        reviewPromptCoordinatorProvider.overrideWithValue(
          reviewPromptCoordinator,
        ),
        infoVersionProvider.overrideWithBuild((ref, notifier) {
          return InfoVersion().build().copyWith(
            version: packageInfo.version,
            buildNumber: int.tryParse(packageInfo.buildNumber) ?? 1,
          );
        }),
      ],
      child: EasyLocalization(
        supportedLocales: const [
          Locale('en'),
          Locale('es'),
          Locale('pt', 'BR'),
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: MainApp(),
      ),
    ),
  );
}
