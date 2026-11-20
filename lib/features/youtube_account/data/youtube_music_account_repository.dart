import 'dart:convert';

import 'package:flow_music/features/autoplay/data/mix_playlist_repository.dart';
import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_cookie.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_library_parser.dart';
import 'package:http/http.dart' as http;

/// YouTube rechazo la sesion: la cookie caduco o se cerro la sesion.
/// Prefijo de las radios de la cuenta; distingue sus paginas de las de los
/// mixes anonimos (`RD<id>`), que se piden a otro servidor.
const radioPlaylistPrefix = 'RDAMVM';

class YouTubeMusicSessionExpired implements Exception {
  const YouTubeMusicSessionExpired();
}

/// Lee la biblioteca de la cuenta con la API interna de YouTube Music, la
/// misma que usa music.youtube.com con la sesion iniciada.
class YouTubeMusicAccountRepository {
  YouTubeMusicAccountRepository(
    this._cookie, {
    http.Client? client,
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;

  static const _parser = YouTubeMusicLibraryParser();
  static const _libraryPlaylistsId = 'FEmusic_liked_playlists';
  static const _homeId = 'FEmusic_home';
  static const _artistsId = 'FEmusic_library_corpus_artists';

  /// El Inicio sigue cargando filas casi sin fin; cuatro paginas bastan.
  static const _maxHomePages = 4;
  static const _clientVersion = '1.20250101.01.00';
  static const _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36';

  /// Canciones por peticion al editar una lista.
  static const _editBatchSize = 100;

  /// Tope de paginas por lista (unas 100 canciones cada una).
  static const _maxPages = 20;

  final YouTubeMusicCookie _cookie;
  final http.Client _client;
  final DateTime Function() _clock;

  Future<List<YouTubeMusicPlaylist>> fetchPlaylists() {
    return _fetchAll(_libraryPlaylistsId, _parser.parsePlaylists);
  }

  /// Canciones de una lista. Los mixes (`RD...`) no son listas guardadas:
  /// YouTube los arma al momento como cola de reproduccion.
  Future<List<YouTubeSearchSuggestion>> fetchPlaylistTracks(String id) async {
    if (id.startsWith('RD')) {
      return _parser.parseMixTracks(
        await _post('next', {
          'playlistId': id,
          'enablePersistentPlaylistPanel': true,
          'isAudioOnly': true,
        }),
      );
    }
    return _fetchAll('VL$id', _parser.parseTracks);
  }

  /// Marca una cancion con «Me gusta» en la cuenta.
  Future<void> like(String videoId) async {
    await _post('like/like', {
      'target': {'videoId': videoId},
    });
  }

  /// Crea una lista privada vacia y devuelve su id.
  Future<String> createPlaylist(String title, String description) async {
    final data = await _post('playlist/create', {
      'title': title,
      'description': description,
      'privacyStatus': 'PRIVATE',
    });
    final id = data is Map ? data['playlistId'] : null;
    if (id is! String || id.isEmpty) {
      throw StateError('YouTube Music no devolvio la lista creada');
    }
    return id;
  }

  /// Agrega canciones a una lista de la cuenta, en tandas, saltando las que
  /// ya esten en ella.
  Future<void> addToPlaylist(String playlistId, List<String> videoIds) async {
    for (var start = 0; start < videoIds.length; start += _editBatchSize) {
      final batch = videoIds.skip(start).take(_editBatchSize);
      final data = await _post('browse/edit_playlist', {
        'playlistId': playlistId,
        'actions': [
          for (final videoId in batch)
            {
              'action': 'ACTION_ADD_VIDEO',
              'addedVideoId': videoId,
              'dedupeOption': 'DEDUPE_OPTION_SKIP',
            },
        ],
      });
      final status = data is Map ? data['status'] : null;
      if (status != 'STATUS_SUCCEEDED') {
        throw StateError('YouTube Music no agrego las canciones: $status');
      }
    }
  }

  /// Nombre y foto de la cuenta, para el avatar.
  Future<YouTubeMusicAccountInfo?> fetchAccount() async {
    return _parser.parseAccount(await _post('account/account_menu', {}));
  }

  /// Ids de los artistas a los que la cuenta esta suscrita.
  Future<List<String>> fetchSubscribedArtists() {
    return _fetchAll(_artistsId, _parser.parseSubscribedArtists);
  }

  /// Radio de una cancion armada con los gustos de la cuenta, como la que
  /// sigue sonando en YouTube Music al terminar una cancion.
  Future<MixPlaylistPage> fetchRadio(String videoId) async {
    final playlistId = '$radioPlaylistPrefix$videoId';
    final page = _parser.parseRadio(
      await _post('next', {
        'videoId': videoId,
        'playlistId': playlistId,
        'enablePersistentPlaylistPanel': true,
        'isAudioOnly': true,
      }),
    );
    return _radioPage(playlistId, page);
  }

  /// Siguiente pagina de una radio pedida con [fetchRadio].
  Future<MixPlaylistPage> fetchRadioPage(
    String playlistId,
    String continuation,
  ) async {
    final page = _parser.parseRadio(
      await _post('next', {
        'continuation': continuation,
        'playlistId': playlistId,
        'enablePersistentPlaylistPanel': true,
        'isAudioOnly': true,
      }, continuation),
    );
    return _radioPage(playlistId, page);
  }

  MixPlaylistPage _radioPage(
    String playlistId,
    YouTubeMusicPage<YouTubeSearchSuggestion> page,
  ) {
    return MixPlaylistPage(
      playlistId: playlistId,
      tracks: page.items,
      nextPageToken: page.continuation,
    );
  }

  /// Inicio personalizado de la cuenta, el mismo de music.youtube.com.
  Future<List<YouTubeMusicHomeShelf>> fetchHome() {
    return _fetchAll(_homeId, _parser.parseHome, maxPages: _maxHomePages);
  }

  Future<List<T>> _fetchAll<T>(
    String browseId,
    YouTubeMusicPage<T> Function(Object? data) parse, {
    int maxPages = _maxPages,
  }) async {
    final items = <T>[];
    var page = parse(await _post('browse', {'browseId': browseId}));
    items.addAll(page.items);
    for (var i = 1; i < maxPages; i++) {
      final token = page.continuation;
      if (token == null) break;
      page = parse(await _post('browse', {'continuation': token}, token));
      if (page.items.isEmpty) break;
      items.addAll(page.items);
    }
    return List.unmodifiable(items);
  }

  /// [continuation] va tambien en la URL: los tokens antiguos
  /// (`nextContinuationData`) solo se leen de ahi y los nuevos del cuerpo.
  Future<Object?> _post(
    String endpoint,
    Map<String, Object?> request, [
    String? continuation,
  ]) async {
    final uri = Uri.https('music.youtube.com', '/youtubei/v1/$endpoint', {
      'prettyPrint': 'false',
      if (continuation != null) ...{
        'ctoken': continuation,
        'continuation': continuation,
        'type': 'next',
      },
    });
    final response = await _client.post(
      uri,
      headers: {
        'content-type': 'application/json',
        'accept-language': 'es-419,es;q=0.9,en;q=0.8',
        'user-agent': _userAgent,
        ..._cookie.sessionHeaders(YouTubeMusicCookie.origin, _clock()),
      },
      body: jsonEncode({
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': _clientVersion,
            'hl': 'es',
          },
        },
        ...request,
      }),
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const YouTubeMusicSessionExpired();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Unexpected status code: ${response.statusCode}',
        uri,
      );
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (!_isLoggedIn(data)) throw const YouTubeMusicSessionExpired();
    return data;
  }

  /// Con una cookie vencida YouTube responde 200 como invitado; lo delata
  /// `responseContext.serviceTrackingParams` con `logged_in = 0`.
  bool _isLoggedIn(Object? data) {
    final context = data is Map ? data['responseContext'] : null;
    final services = context is Map ? context['serviceTrackingParams'] : null;
    if (services is! List) return true;
    for (final service in services) {
      final params = service is Map ? service['params'] : null;
      if (params is! List) continue;
      for (final param in params) {
        if (param is Map && param['key'] == 'logged_in') {
          return param['value'] == '1';
        }
      }
    }
    return true;
  }
}
