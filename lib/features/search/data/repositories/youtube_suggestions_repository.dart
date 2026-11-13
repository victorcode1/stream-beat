import 'dart:convert';

import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/features/search/data/repositories/piped_video_duration.dart';
import 'package:flow_music/features/search/data/repositories/youtube_music_search_parser.dart';
import 'package:flow_music/features/search/data/repositories/youtube_search_page_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _maxSuggestions = 12;
const _minSongDuration = Duration(minutes: 1);
const _maxSongDuration = Duration(minutes: 12);
const _youtubeSearchHost = 'www.youtube.com';
const _youtubeSearchPath = '/results';
const _pipedApiBaseUrl = 'https://api.piped.private.coffee';
const _userAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36';

const _searchPageParser = YouTubeSearchPageParser();
const _musicSearchParser = YouTubeMusicSearchParser();

/// Resultados que muestra la busqueda del usuario.
const _maxUserResults = 30;
const _maxMusicResults = 12;

/// Los Shorts no son canciones; todo lo demas (mixes, sets, albumes) si se
/// muestra aunque dure mas de 12 minutos.
const _minUserResultDuration = Duration(seconds: 30);
const _searchTimeout = Duration(seconds: 10);

/// Filtro «Canciones» de YouTube Music.
const _musicSongsFilter = 'EgWKAQIIAWoKEAkQBRAKEAMQBA%3D%3D';

/// Busqueda del usuario: lo que escribe, tal cual.
///
/// En modo audio consulta en paralelo YouTube Music (canciones oficiales,
/// ~13 KB por busqueda) y la API de YouTube (todo lo demas, ~60 KB), y las
/// mezcla sin duplicados con las canciones primero. Antes se descargaba la
/// pagina HTML de resultados (~300 KB) con «cancion» agregado a la consulta y
/// se descartaba lo que durara mas de 12 minutos, asi que muchas cosas que
/// existen en YouTube no aparecian. En modo video solo usa YouTube.
Future<List<YouTubeSearchSuggestion>> searchSongsAndVideos(
  String query, {
  required bool includeMusic,
}) async {
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty) return const [];
  if (kIsWeb) return _fetchPipedSearchSuggestions(trimmedQuery);

  final results = await Future.wait([
    if (includeMusic)
      _guardSearch('YouTube Music', () => _fetchMusicSongs(trimmedQuery))
    else
      Future.value(const <YouTubeSearchSuggestion>[]),
    _guardSearch('YouTube API', () => _fetchYoutubeApiResults(trimmedQuery)),
  ]);

  final merged = mergeSearchResults(results, limit: _maxUserResults);
  if (merged.isNotEmpty) return merged;

  // Si las dos APIs fallan, la busqueda anterior sigue siendo el respaldo.
  return fetchYouTubeSearchSuggestions(
    '$trimmedQuery ${includeMusic ? 'cancion' : 'video'}',
    source: 'searchSongsAndVideos.fallback',
  );
}

/// Une varias listas en orden, sin repetir videos, hasta [limit].
@visibleForTesting
List<YouTubeSearchSuggestion> mergeSearchResults(
  List<List<YouTubeSearchSuggestion>> sources, {
  required int limit,
}) {
  final merged = <YouTubeSearchSuggestion>[];
  final seenVideoIds = <String>{};
  for (final source in sources) {
    for (final suggestion in source) {
      if (!seenVideoIds.add(suggestion.videoId)) continue;
      merged.add(suggestion);
      if (merged.length >= limit) return List.unmodifiable(merged);
    }
  }
  return List.unmodifiable(merged);
}

Future<List<YouTubeSearchSuggestion>> _guardSearch(
  String label,
  Future<List<YouTubeSearchSuggestion>> Function() search,
) async {
  try {
    return await search().timeout(_searchTimeout);
  } catch (error) {
    debugPrint('$label search failed: $error');
    return const [];
  }
}

Future<List<YouTubeSearchSuggestion>> _fetchMusicSongs(String query) async {
  final data = await _postInnertube(
    Uri.https('music.youtube.com', '/youtubei/v1/search', {
      'prettyPrint': 'false',
    }),
    {
      'context': {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20250101.01.00',
          'hl': 'es',
        },
      },
      'query': query,
      'params': _musicSongsFilter,
    },
  );
  return _musicSearchParser.parseSuggestions(data, limit: _maxMusicResults);
}

Future<List<YouTubeSearchSuggestion>> _fetchYoutubeApiResults(
  String query,
) async {
  final data = await _postInnertube(
    Uri.https(_youtubeSearchHost, '/youtubei/v1/search', {
      'prettyPrint': 'false',
    }),
    {
      'context': {
        'client': {
          'clientName': 'WEB',
          'clientVersion': '2.20250101.00.00',
          'hl': 'es',
        },
      },
      'query': query,
    },
  );
  return _searchPageParser.parseSuggestionsFromData(
    data,
    limit: _maxUserResults,
    minDuration: _minUserResultDuration,
    maxDuration: null,
  );
}

Future<Object?> _postInnertube(Uri uri, Map<String, Object?> body) async {
  final response = await http.post(
    uri,
    headers: const {
      'content-type': 'application/json',
      'accept-language': 'es-419,es;q=0.9,en;q=0.8',
      'user-agent': _userAgent,
    },
    body: jsonEncode(body),
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw http.ClientException(
      'Unexpected status code: ${response.statusCode}',
      uri,
    );
  }
  return jsonDecode(utf8.decode(response.bodyBytes));
}

Future<List<YouTubeSearchSuggestion>> fetchYouTubeSearchSuggestions(
  String query, {
  String source = 'YouTubeSearch',
}) async {
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty) return const [];
  if (kIsWeb) {
    return _fetchPipedSearchSuggestions(trimmedQuery);
  }

  try {
    final uri = Uri.https(_youtubeSearchHost, _youtubeSearchPath, {
      'search_query': trimmedQuery,
    });
    final response = await http.get(
      uri,
      headers: const {
        'accept-language': 'en-US,en;q=0.9',
        'user-agent': _userAgent,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Unexpected status code: ${response.statusCode}',
        uri,
      );
    }

    return _searchPageParser.parseSuggestions(
      response.body,
      limit: _maxSuggestions,
    );
  } catch (error, stackTrace) {
    debugPrint('YouTube search failed ($source): $error');
    debugPrintStack(stackTrace: stackTrace);
    throw Exception('Failed to search YouTube videos.');
  }
}

Future<List<YouTubeSearchSuggestion>> _fetchPipedSearchSuggestions(
  String query,
) async {
  final uri = pipedSearchUriForQuery(query);
  final response = await http.get(uri);

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw http.ClientException(
      'Unexpected Piped status code: ${response.statusCode}',
      uri,
    );
  }

  final decoded = jsonDecode(response.body);
  final items = decoded is Map<String, dynamic> ? decoded['items'] : null;
  if (items is! List) return const [];

  final suggestions = <YouTubeSearchSuggestion>[];
  final seenVideoIds = <String>{};
  for (final item in items) {
    if (item is! Map) continue;
    final typedItem = Map<String, dynamic>.from(item);
    if (typedItem['type'] != 'stream') continue;

    final videoId = extractPipedVideoId(typedItem['url']);
    final title = typedItem['title'] as String? ?? '';
    if (videoId.isEmpty || title.isEmpty || !seenVideoIds.add(videoId)) {
      continue;
    }

    final duration = parsePipedDuration(typedItem['duration']);
    if (duration != null &&
        (duration < _minSongDuration || duration > _maxSongDuration)) {
      continue;
    }

    suggestions.add(
      YouTubeSearchSuggestion(
        videoId: videoId,
        displayText: title,
        channelTitle: typedItem['uploaderName'] as String? ?? '',
        thumbnailUrl: _youtubeThumbnailUrl(videoId),
        duration: duration,
      ),
    );
    if (suggestions.length >= _maxSuggestions) break;
  }

  return List.unmodifiable(suggestions);
}

@visibleForTesting
Uri pipedSearchUriForQuery(String query) {
  return Uri.parse(
    '$_pipedApiBaseUrl/search',
  ).replace(queryParameters: {'q': query, 'filter': 'all'});
}

String _youtubeThumbnailUrl(String videoId) {
  return 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
}
