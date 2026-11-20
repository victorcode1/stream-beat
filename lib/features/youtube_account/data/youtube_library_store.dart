import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_library_parser.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

const String youtubeLibraryBoxName = 'youtube_library';

/// Lista de la cuenta de YouTube guardada en el dispositivo con sus
/// canciones, para verla y reproducirla sin volver a pedirla.
class SavedYouTubePlaylist {
  const SavedYouTubePlaylist({required this.playlist, required this.tracks});

  final YouTubeMusicPlaylist playlist;
  final List<YouTubeSearchSuggestion> tracks;
}

/// Copia local de la biblioteca de YouTube (apartado «YouTube»). Cada
/// sincronizacion la reemplaza entera, en el orden de la cuenta.
class YouTubeLibraryStore {
  const YouTubeLibraryStore();

  static const _playlistsKey = 'playlists';
  static const _syncedAtKey = 'synced_at_ms';

  Box get _box => Hive.box(youtubeLibraryBoxName);

  List<SavedYouTubePlaylist> readAll() {
    final raw = _box.get(_playlistsKey);
    if (raw is! List) return const [];
    return List.unmodifiable(
      raw.whereType<Map>().map(_decodePlaylist).nonNulls,
    );
  }

  Future<void> replaceAll(List<SavedYouTubePlaylist> playlists) {
    return _box.put(_playlistsKey, [
      for (final saved in playlists) _encodePlaylist(saved),
    ]);
  }

  /// Hora de la ultima sincronizacion correcta; null si nunca se hizo.
  DateTime? readSyncedAt() {
    final ms = _box.get(_syncedAtKey);
    return ms is int ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  Future<void> writeSyncedAt(DateTime time) {
    return _box.put(_syncedAtKey, time.millisecondsSinceEpoch);
  }

  Future<void> clear() => _box.deleteAll([_playlistsKey, _syncedAtKey]);

  Map<String, Object?> _encodePlaylist(SavedYouTubePlaylist saved) {
    final playlist = saved.playlist;
    return {
      'id': playlist.id,
      'title': playlist.title,
      'subtitle': playlist.subtitle,
      'thumbnailUrl': playlist.thumbnailUrl,
      'tracks': [
        for (final song in saved.tracks)
          {
            'videoId': song.videoId,
            'title': song.displayText,
            'author': song.channelTitle,
            'thumbnailUrl': song.thumbnailUrl,
            'durationMs': song.duration?.inMilliseconds,
          },
      ],
    };
  }

  SavedYouTubePlaylist? _decodePlaylist(Map<dynamic, dynamic> raw) {
    final id = raw['id'];
    final title = raw['title'];
    if (id is! String || id.isEmpty || title is! String) return null;
    final tracks = raw['tracks'];
    return SavedYouTubePlaylist(
      playlist: YouTubeMusicPlaylist(
        id: id,
        title: title,
        subtitle: raw['subtitle'] as String? ?? '',
        thumbnailUrl: raw['thumbnailUrl'] as String? ?? '',
      ),
      tracks: List.unmodifiable(
        (tracks is List ? tracks : const [])
            .whereType<Map>()
            .map(_decodeTrack)
            .nonNulls,
      ),
    );
  }

  YouTubeSearchSuggestion? _decodeTrack(Map<dynamic, dynamic> raw) {
    final videoId = raw['videoId'];
    if (videoId is! String || videoId.isEmpty) return null;
    final durationMs = raw['durationMs'];
    return YouTubeSearchSuggestion(
      videoId: videoId,
      displayText: raw['title'] as String? ?? '',
      channelTitle: raw['author'] as String? ?? '',
      thumbnailUrl: raw['thumbnailUrl'] as String? ?? '',
      duration: durationMs is int ? Duration(milliseconds: durationMs) : null,
    );
  }
}
