import 'package:flow_music/features/account/domain/entities/local_user_data.dart';
import 'package:flow_music/features/radio/data/radio_favorites_repository.dart';
import 'package:flow_music/features/radio/data/radio_playlists_repository.dart';
import 'package:flow_music/features/settings/data/settings_local_data_source.dart';
import 'package:flow_music/features/settings/data/settings_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Conserva la biblioteca del dispositivo y sus archivos locales históricos.
class UserDataLocalStore {
  const UserDataLocalStore({
    this.favorites = const RadioFavoritesRepository(),
    this.playlists = const RadioPlaylistsRepository(),
    this.preferences = const SettingsLocalDataSource(),
  });

  // Preserve these keys so an update can still read existing device archives.
  static const _ownerKey = 'user_data_sync_owner_id';
  static const _pendingSwitchKey = 'user_data_local_pending_switch';
  static String _archiveKey(String? userId) =>
      'user_data_local_account_${userId ?? "guest"}';

  final RadioFavoritesRepository favorites;
  final RadioPlaylistsRepository playlists;
  final SettingsLocalDataSource preferences;

  Box get _metadata => Hive.box(settingsBoxName);

  String? get ownerId {
    final value = _metadata.get(_ownerKey);
    return value is String && value.isNotEmpty ? value : null;
  }

  LocalUserData read() => LocalUserData(
    favorites: favorites.readAll(),
    playlists: playlists.readAll(),
    preferences: preferences.read(),
  );

  Future<void> archiveCurrent() =>
      _metadata.put(_archiveKey(ownerId), {'snapshot': read().toJson()});

  /// Recupera escrituras pendientes y conserva la biblioteca visible al retirar
  /// las cuentas. Los archivos de otras bibliotecas históricas no se eliminan.
  Future<bool> prepareDeviceLibrary() async {
    final recovered = await _recoverPendingSwitch();
    if (ownerId == null) return recovered;
    await archiveCurrent();
    await _metadata.delete(_ownerKey);
    return true;
  }

  LocalUserData? _archivedSnapshot(Object? archive) =>
      archive is Map && archive['snapshot'] is Map
      ? LocalUserData.fromJson(
          Map<String, dynamic>.from(archive['snapshot'] as Map),
        )
      : null;

  Future<bool> _recoverPendingSwitch() async {
    final pending = _metadata.get(_pendingSwitchKey);
    if (pending is! Map) return false;
    final snapshot = _archivedSnapshot(pending);
    if (snapshot == null) throw StateError('Invalid local account transition');
    final targetUserId = pending['user_id'] as String?;
    await apply(snapshot);
    if (targetUserId == null) {
      await _metadata.delete(_ownerKey);
    } else {
      await _metadata.put(_ownerKey, targetUserId);
    }
    if (pending['adopted_guest'] == true) {
      await _metadata.delete(_archiveKey(null));
    }
    final deletedUserId = pending['deleted_user_id'] as String?;
    if (deletedUserId != null) {
      await _metadata.delete(_archiveKey(deletedUserId));
    }
    await _metadata.delete(_pendingSwitchKey);
    return true;
  }

  Future<void> apply(LocalUserData snapshot) async {
    await favorites.replaceAll(snapshot.favorites);
    await playlists.replaceAll(snapshot.playlists);
    await preferences.clear();
    if (!snapshot.preferences.isEmpty) {
      await preferences.write(snapshot.preferences);
    }
  }
}
