import 'package:flow_music/features/account/data/user_data_local_store.dart';
import 'package:flow_music/features/account/domain/entities/local_user_data.dart';
import 'package:flutter/foundation.dart';

/// Serializa las operaciones de la biblioteca del dispositivo, sin cuentas.
class LocalUserDataCoordinator {
  LocalUserDataCoordinator(
    this._local, {
    required VoidCallback onLocalDataChanged,
  }) : _onLocalDataChanged = onLocalDataChanged;

  final UserDataLocalStore _local;
  final VoidCallback _onLocalDataChanged;
  Future<void> _serial = Future<void>.value();
  bool _initialized = false;
  bool _disposed = false;

  Future<void> _prepare() async {
    if (_initialized) return;
    final changed = await _local.prepareDeviceLibrary();
    _initialized = true;
    if (changed && !_disposed) _onLocalDataChanged();
  }

  Future<void> initialize() => _enqueue(_prepare);

  Future<T> editFavorites<T>(Future<T> Function() edit) => _edit(edit);
  Future<T> editPlaylists<T>(Future<T> Function() edit) => _edit(edit);
  Future<T> editPreferences<T>(Future<T> Function() edit) => _edit(edit);

  Future<T> _edit<T>(Future<T> Function() edit) => _enqueue(() async {
    await _prepare();
    final result = await edit();
    await _local.archiveCurrent();
    return result;
  });

  Future<LocalUserData> readCurrentUser() => _enqueue(() async {
    await _prepare();
    return _local.read();
  });

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    if (_disposed) return Future.error(StateError('Local store is disposed'));
    final result = _serial.then((_) => operation());
    _serial = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void dispose() => _disposed = true;
}
