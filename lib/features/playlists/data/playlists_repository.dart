import 'dart:convert';

import 'package:flow_music/features/playlists/data/playlist.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

const String playlistsBoxName = 'playlists';
// Ignore metadata left by older versions without deleting local data.
const String _legacyOwnerUidKey = '__owner_uid';

class PlaylistsRepository {
  const PlaylistsRepository();

  static Playlist? decodePlaylistJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return Playlist.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Box get _box => Hive.box(playlistsBoxName);

  List<Playlist> readAll() {
    final result = <Playlist>[];
    for (final key in _box.keys) {
      if (key == _legacyOwnerUidKey) continue;
      final raw = _box.get(key);
      final playlist = _decode(raw);
      if (playlist != null) result.add(playlist);
    }
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(result);
  }

  Future<void> save(Playlist playlist) async {
    if (playlist.id.isEmpty) return;
    await _box.put(playlist.id, jsonEncode(playlist.toJson()));
  }

  Future<void> delete(String playlistId) async {
    if (playlistId.isEmpty) return;
    await _box.delete(playlistId);
  }

  Playlist? _decode(Object? raw) {
    try {
      if (raw is! String || raw.isEmpty) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return Playlist.fromJson(json);
    } catch (error, stackTrace) {
      debugPrint('PlaylistsRepository decode failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }
}
