import 'dart:async';
import 'dart:io';
import 'package:flow_music/features/account/application/local_user_data_coordinator.dart';
import 'package:flow_music/features/account/data/user_data_local_store.dart';
import 'package:flow_music/features/account/domain/entities/local_user_data.dart';
import 'package:flow_music/features/radio/data/models/radio_playlist.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/data/radio_favorites_repository.dart';
import 'package:flow_music/features/radio/data/radio_playlists_repository.dart';
import 'package:flow_music/features/settings/data/settings_storage.dart';
import 'package:flow_music/features/settings/data/user_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

const local = UserDataLocalStore();

void main() {
  late Directory directory;
  late LocalUserDataCoordinator coordinator;

  Future<void> openStore() async {
    Hive.init(directory.path);
    await Hive.openBox(settingsBoxName);
    await Hive.openBox(radioFavoritesBoxName);
    await Hive.openBox(radioPlaylistsBoxName);
  }

  LocalUserDataCoordinator makeCoordinator() =>
      LocalUserDataCoordinator(local, onLocalDataChanged: () {});

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('streambeat_local_');
    await openStore();
    coordinator = makeCoordinator();
  });

  tearDown(() async {
    coordinator.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'removing accounts preserves the visible library and legacy archives',
    () async {
      final box = Hive.box(settingsBoxName);
      await box.put('user_data_sync_owner_id', 'previous-user');
      await box.put('user_data_local_account_other-user', {
        'snapshot': snapshot('other').toJson(),
      });
      await local.apply(snapshot('existing'));
      await coordinator.initialize();
      expect(local.read().favorites.single.stationUuid, 'existing');
      expect(
        local.read().playlists.single.items.single.stationUuid,
        'existing',
      );
      expect(local.read().preferences.locale, 'es');
      expect(local.ownerId, isNull);
      expect(box.get('user_data_local_account_previous-user'), isNotNull);
      expect(box.get('user_data_local_account_other-user'), isNotNull);
    },
  );

  test(
    'device restart retains favorites playlists and settings without an account',
    () async {
      await coordinator.editFavorites(
        () => local.favorites.toggle(station('saved')),
      );
      await coordinator.editPlaylists(
        () => local.playlists.save(playlist('saved')),
      );
      await coordinator.editPreferences(
        () => local.preferences.write(
          const UserSettings(locale: 'pt-BR', autoplayEnabled: false),
        ),
      );
      coordinator.dispose();
      await Hive.close();
      await openStore();
      coordinator = makeCoordinator();
      await coordinator.initialize();
      expect(local.read().favorites.single.stationUuid, 'saved');
      expect(local.read().playlists.single.items.single.stationUuid, 'saved');
      expect(local.read().preferences.locale, 'pt-BR');
      expect(local.read().preferences.autoplayEnabled, isFalse);
    },
  );

  test(
    'recovers an interrupted legacy transition before using device library',
    () async {
      final box = Hive.box(settingsBoxName);
      await box.put('user_data_local_pending_switch', {
        'user_id': 'previous-user',
        'snapshot': snapshot('recovered').toJson(),
      });
      await coordinator.initialize();
      expect(local.read().favorites.single.stationUuid, 'recovered');
      expect(local.ownerId, isNull);
      expect(box.containsKey('user_data_local_pending_switch'), isFalse);
      await coordinator.initialize();
      expect(local.read().favorites.single.stationUuid, 'recovered');
    },
  );

  test('serializes edits without losing either result', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final first = coordinator.editFavorites(() async {
      entered.complete();
      await release.future;
      await local.favorites.toggle(station('first'));
    });
    await entered.future;
    final second = coordinator.editFavorites(
      () => local.favorites.toggle(station('second')),
    );
    release.complete();
    await Future.wait([first, second]);
    expect(
      local.read().favorites.map((s) => s.stationUuid),
      containsAll(['first', 'second']),
    );
  });

  test('failed local edit does not poison later writes', () async {
    await expectLater(
      coordinator.editFavorites<void>(
        () async => throw StateError('disk failure'),
      ),
      throwsStateError,
    );
    await coordinator.editFavorites(
      () => local.favorites.toggle(station('later')),
    );
    expect(local.read().favorites.single.stationUuid, 'later');
  });
}

RadioStation station(String id) => RadioStation.fromJson({
  'stationuuid': id,
  'name': 'Station $id',
  'url': 'https://example.com/$id',
  '__favorited_at': DateTime.utc(2026).toIso8601String(),
});

RadioPlaylist playlist(String id) => RadioPlaylist(
  id: 'list-$id',
  name: 'My radios',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  items: [station(id)],
);

LocalUserData snapshot(String id) => LocalUserData(
  favorites: [station(id)],
  playlists: [playlist(id)],
  preferences: const UserSettings(
    locale: 'es',
    themeMode: 'dark',
    updatedAtMs: 1,
  ),
);
