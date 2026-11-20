import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/features/youtube_account/data/youtube_library_store.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_account_repository.dart';

/// Prefijo de las listas que StreamBeat crea en la cuenta. YouTube Music no
/// tiene carpetas: el nombre es lo que las agrupa.
const streamBeatPlaylistPrefix = 'StreamBeat Music · ';

/// Id de la lista «Me gusta» de YouTube Music.
const youtubeLikedPlaylistId = 'LM';

/// Una lista de la Biblioteca de la app para copiar a YouTube Music.
class StreamBeatSyncList {
  const StreamBeatSyncList({required this.name, required this.videoIds});

  /// Nombre en la app («Para correr»...); en YouTube lleva el prefijo.
  final String name;
  final List<String> videoIds;

  String get title => '$streamBeatPlaylistPrefix$name';
}

/// Lo que trajo y lo que envio una sincronizacion.
class YouTubeMusicSyncResult {
  const YouTubeMusicSyncResult({
    required this.library,
    required this.likedSongs,
    required this.likesSent,
    required this.playlistsCreated,
    required this.songsSent,
  });

  /// Listas de la cuenta para el apartado «YouTube» (sin las de StreamBeat).
  final List<SavedYouTubePlaylist> library;

  /// Canciones con «Me gusta» en YouTube, para sumarlas a Favoritas.
  final List<YouTubeSearchSuggestion> likedSongs;

  /// Favoritas de la app marcadas con «Me gusta» en YouTube.
  final int likesSent;

  /// Listas de la app creadas en YouTube.
  final int playlistsCreated;

  /// Canciones de listas de la app agregadas en YouTube.
  final int songsSent;
}

/// Sincroniza la app con la cuenta de YouTube Music en los dos sentidos:
/// favoritas con «Me gusta» y Biblioteca con las listas de la cuenta.
///
/// Solo suma: nunca quita «Me gusta» ni canciones en YouTube, asi que
/// repetirla no duplica ni pierde nada.
class YouTubeMusicSync {
  const YouTubeMusicSync(this._repository);

  static const _description = 'Sincronizada desde StreamBeat Music.';

  final YouTubeMusicAccountRepository _repository;

  Future<YouTubeMusicSyncResult> run({
    required List<String> favoriteIds,
    required List<StreamBeatSyncList> playlists,
  }) async {
    // 1. Bajar: listas de la cuenta y sus canciones. Las que creo StreamBeat
    //    ya estan en la Biblioteca de la app; solo se recuerda su id.
    final library = <SavedYouTubePlaylist>[];
    final streamBeatLists = <String, String>{};
    List<YouTubeSearchSuggestion>? likedSongs;
    for (final playlist in await _repository.fetchPlaylists()) {
      if (playlist.title.startsWith(streamBeatPlaylistPrefix)) {
        streamBeatLists.putIfAbsent(playlist.title, () => playlist.id);
        continue;
      }
      final tracks = await _repository.fetchPlaylistTracks(playlist.id);
      if (playlist.id == youtubeLikedPlaylistId) likedSongs = tracks;
      library.add(SavedYouTubePlaylist(playlist: playlist, tracks: tracks));
    }
    likedSongs ??= await _repository.fetchPlaylistTracks(
      youtubeLikedPlaylistId,
    );

    // 2. Subir favoritas que aun no tienen «Me gusta».
    final liked = {for (final song in likedSongs) song.videoId};
    final toLike = {
      for (final id in favoriteIds)
        if (id.isNotEmpty && !liked.contains(id)) id,
    };
    for (final videoId in toLike) {
      await _repository.like(videoId);
    }

    // 3. Subir listas de la app, sumando lo que les falte.
    var created = 0;
    var songsSent = 0;
    for (final list in playlists) {
      final videoIds = {
        for (final id in list.videoIds)
          if (id.isNotEmpty) id,
      };
      if (videoIds.isEmpty) continue;

      var playlistId = streamBeatLists[list.title];
      final present = <String>{};
      if (playlistId == null) {
        playlistId = await _repository.createPlaylist(list.title, _description);
        streamBeatLists[list.title] = playlistId;
        created++;
      } else {
        final tracks = await _repository.fetchPlaylistTracks(playlistId);
        present.addAll(tracks.map((song) => song.videoId));
      }

      final missing = videoIds.difference(present).toList();
      if (missing.isEmpty) continue;
      await _repository.addToPlaylist(playlistId, missing);
      songsSent += missing.length;
    }

    return YouTubeMusicSyncResult(
      library: List.unmodifiable(library),
      likedSongs: likedSongs,
      likesSent: toLike.length,
      playlistsCreated: created,
      songsSent: songsSent,
    );
  }
}
