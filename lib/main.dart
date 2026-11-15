import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/app/app.dart';
import 'package:flow_music/core/audio/background_audio_handler.dart';
import 'package:flow_music/features/autoplay/data/audio_cache_stub.dart'
    if (dart.library.io) 'package:flow_music/features/autoplay/data/audio_cache_io.dart';
import 'package:flow_music/features/favorites/data/favorites_repository.dart';
import 'package:flow_music/features/home/data/home_suggestions_cache.dart';
import 'package:flow_music/features/history/data/playback_history_repository.dart';
import 'package:flow_music/features/playlists/data/playlists_repository.dart';
import 'package:flow_music/features/radio/data/radio_favorites_repository.dart';
import 'package:flow_music/features/radio/data/radio_playlists_repository.dart';
import 'package:flow_music/features/search/data/search_history_repository.dart';
import 'package:flow_music/features/settings/presentation/controllers/theme_mode_controller.dart';
import 'package:flow_music/shared/custom_info_version/provider/info_version.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await initializeDateFormatting();
  await Hive.initFlutter();
  await Hive.openBox(settingsBoxName);
  await Hive.openBox(favoritesBoxName);
  await Hive.openBox(playlistsBoxName);
  await Hive.openBox(playbackHistoryBoxName);
  await Hive.openBox(homeSuggestionsCacheBoxName);
  await Hive.openBox(radioFavoritesBoxName);
  await Hive.openBox(radioPlaylistsBoxName);
  await Hive.openBox(searchHistoryBoxName);
  await initFlowAudioHandler();
  // The autoplay cache is per-session. If a previous run left files behind
  // (e.g. crash before the detach lifecycle fired), drop them now so storage
  // can't grow across launches.
  await clearAudioCache();
  final packageInfo = await PackageInfo.fromPlatform();

  runApp(
    ProviderScope(
      overrides: [
        infoVersionProvider.overrideWithBuild((ref, notifier) {
          return InfoVersion().build().copyWith(
            version: packageInfo.version,
            buildNumber: int.tryParse(packageInfo.buildNumber) ?? 1,
          );
        }),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('es')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: MainApp(),
      ),
    ),
  );
}
