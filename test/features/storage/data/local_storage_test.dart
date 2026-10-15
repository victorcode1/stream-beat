import 'dart:io';

import 'package:flow_music/features/favorites/data/favorite_song.dart';
import 'package:flow_music/features/favorites/data/favorites_repository.dart';
import 'package:flow_music/features/playlists/data/playlist.dart';
import 'package:flow_music/features/playlists/data/playlists_repository.dart';
import 'package:flow_music/features/radio/data/models/radio_playlist.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/data/radio_favorites_repository.dart';
import 'package:flow_music/features/radio/data/radio_playlists_repository.dart';
import 'package:flow_music/features/settings/data/settings_local_data_source.dart';
import 'package:flow_music/features/settings/data/user_settings.dart';
import 'package:flow_music/features/settings/presentation/controllers/theme_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

void main() {
  late Directory directory;
  const boxNames = [
    favoritesBoxName,
    playlistsBoxName,
    radioFavoritesBoxName,
    radioPlaylistsBoxName,
    settingsBoxName,
  ];
  const favorites = FavoritesRepository();
  const playlists = PlaylistsRepository();
  const radioFavorites = RadioFavoritesRepository();
  const radioPlaylists = RadioPlaylistsRepository();
  const settings = SettingsLocalDataSource();

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('streambeat_local_');
    Hive.init(directory.path);
    for (final name in boxNames) {
      await Hive.openBox(name);
    }
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('keeps library and preferences on disk across restarts', () async {
    final date = DateTime.utc(2026, 10, 2);
    final favorite = FavoriteSong(
      videoId: 'song-id',
      title: 'Local song',
      author: 'Artist',
      thumbnailUrl: '',
      addedAt: date,
    );
    final playlist = Playlist(
      id: 'playlist-id',
      name: 'Local playlist',
      createdAt: date,
      updatedAt: date,
      items: const [],
    );
    final station = RadioStation.fromJson({
      'stationuuid': 'station-id',
      'name': 'Local station',
      'url': 'https://example.com/radio',
    });
    final radioPlaylist = RadioPlaylist(
      id: 'radio-playlist-id',
      name: 'Local radio playlist',
      createdAt: date,
      updatedAt: date,
      items: [station],
    );
    const preferences = UserSettings(
      themeMode: 'dark',
      locale: 'es',
      autoplayEnabled: false,
      updatedAtMs: 1,
    );

    for (final name in boxNames.take(4)) {
      await Hive.box(name).put('__owner_uid', 'legacy-user');
    }
    await Hive.box(settingsBoxName).put('settings_owner_uid', 'legacy-user');
    await favorites.add(favorite);
    await playlists.save(playlist);
    await radioFavorites.toggle(station);
    await radioPlaylists.save(radioPlaylist);
    await settings.write(preferences);
    await Hive.close();
    for (final name in boxNames) {
      await Hive.openBox(name);
    }

    expect(favorites.readAll().single.toJson(), favorite.toJson());
    expect(playlists.readAll().single.toJson(), playlist.toJson());
    expect(radioFavorites.readAll().single.stationUuid, station.stationUuid);
    expect(radioPlaylists.readAll().single.toJson(), radioPlaylist.toJson());
    expect(settings.read().toJson(), preferences.toJson());
    for (final name in boxNames.take(4)) {
      expect(Hive.box(name).get('__owner_uid'), 'legacy-user');
    }
    expect(Hive.box(settingsBoxName).get('settings_owner_uid'), 'legacy-user');
  });

  test(
    'ignores legacy account metadata without erasing local settings',
    () async {
      for (final name in boxNames.take(4)) {
        await Hive.box(name).put('__owner_uid', 'legacy-user');
      }
      await Hive.box(settingsBoxName).put('settings_owner_uid', 'legacy-user');
      await settings.write(const UserSettings(locale: 'es'));
      await settings.write(const UserSettings(themeMode: 'dark'));

      expect(favorites.readAll(), isEmpty);
      expect(playlists.readAll(), isEmpty);
      expect(radioFavorites.readAll(), isEmpty);
      expect(radioPlaylists.readAll(), isEmpty);
      expect(settings.read().locale, 'es');
      expect(settings.read().themeMode, 'dark');
      expect(
        Hive.box(settingsBoxName).get('settings_owner_uid'),
        'legacy-user',
      );
    },
  );
}
