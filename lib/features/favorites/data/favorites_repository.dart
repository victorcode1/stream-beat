import 'dart:convert';

import 'package:flow_music/features/favorites/data/favorite_song.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Nombre de la caja Hive que persiste favoritos. La caja se abre en
/// `main.dart` antes de runApp.
const String favoritesBoxName = 'favorites';
// Ignore metadata left by older versions without deleting local data.
const String _legacyOwnerUidKey = '__owner_uid';

/// Acceso de bajo nivel a la persistencia de favoritos.
///
/// Toda la UI debe consumir favoritos via el provider Riverpod
/// `favoritesControllerProvider`, no directamente esta clase. Esto vive en
/// la capa data y se mantiene sin dependencia de UI.
class FavoritesRepository {
  const FavoritesRepository();

  Box get _box => Hive.box(favoritesBoxName);

  /// Devuelve todos los favoritos guardados, ordenados de mas reciente a
  /// mas antiguo.
  List<FavoriteSong> readAll() {
    final result = <FavoriteSong>[];
    for (final key in _box.keys) {
      if (key == _legacyOwnerUidKey) continue;
      final raw = _box.get(key);
      final favorite = _decode(raw);
      if (favorite != null) result.add(favorite);
    }
    result.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return List.unmodifiable(result);
  }

  bool contains(String videoId) {
    if (videoId.isEmpty) return false;
    return _box.containsKey(videoId);
  }

  Future<void> add(FavoriteSong favorite) async {
    if (favorite.videoId.isEmpty) return;
    await _box.put(favorite.videoId, jsonEncode(favorite.toJson()));
  }

  Future<void> remove(String videoId) async {
    if (videoId.isEmpty) return;
    await _box.delete(videoId);
  }

  FavoriteSong? _decode(Object? raw) {
    try {
      if (raw is! String || raw.isEmpty) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return FavoriteSong.fromJson(json);
    } catch (error, stackTrace) {
      debugPrint('FavoritesRepository decode failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }
}
