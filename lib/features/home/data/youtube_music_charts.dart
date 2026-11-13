import 'dart:convert';

import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:http/http.dart' as http;

/// Lista de exitos por pais de YouTube Music, ya con el video de cada cancion.
///
/// Son dos llamadas: la pagina de listas del pais (que trae el id de «Las 20
/// tendencias») y esa lista. Antes el home bajaba el top de Apple y hacia una
/// busqueda en YouTube por cada cancion, hasta 16 en total.
Future<List<YouTubeSearchSuggestion>> fetchYouTubeMusicTrending(
  String countryCode, {
  http.Client? client,
}) async {
  final httpClient = client ?? http.Client();
  try {
    final charts = await _browse(httpClient, countryCode, {
      'browseId': 'FEmusic_charts',
      'formData': {
        'selectedValues': [countryCode],
      },
    });
    final playlistId = chartPlaylistIdFrom(charts);
    if (playlistId == null) return const [];

    final playlist = await _browse(httpClient, countryCode, {
      'browseId': playlistId,
    });
    return parseChartTracks(playlist);
  } finally {
    if (client == null) httpClient.close();
  }
}

Future<Object?> _browse(
  http.Client client,
  String countryCode,
  Map<String, Object?> body,
) async {
  final uri = Uri.https('music.youtube.com', '/youtubei/v1/browse', {
    'prettyPrint': 'false',
  });
  final response = await client
      .post(
        uri,
        headers: const {
          'content-type': 'application/json',
          'user-agent': 'Mozilla/5.0',
        },
        body: jsonEncode({
          'context': {
            'client': {
              'clientName': 'WEB_REMIX',
              'clientVersion': '1.20250101.01.00',
              'hl': 'es',
              'gl': countryCode,
            },
          },
          ...body,
        }),
      )
      .timeout(const Duration(seconds: 10));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw http.ClientException(
      'Unexpected status code: ${response.statusCode}',
      uri,
    );
  }
  return jsonDecode(utf8.decode(response.bodyBytes));
}

/// Id de la primera lista de la pagina de exitos («Las 20 tendencias»).
String? chartPlaylistIdFrom(Object? charts) {
  for (final item in _collect(charts, 'musicTwoRowItemRenderer')) {
    final endpoint = item['navigationEndpoint'];
    final browse = endpoint is Map ? endpoint['browseEndpoint'] : null;
    final id = browse is Map ? browse['browseId'] : null;
    if (id is String && id.startsWith('VL')) return id;
  }
  return null;
}

/// Canciones de una lista de YouTube Music, en su orden.
List<YouTubeSearchSuggestion> parseChartTracks(Object? playlist) {
  final tracks = <YouTubeSearchSuggestion>[];
  final seen = <String>{};
  for (final row in _collect(playlist, 'musicResponsiveListItemRenderer')) {
    final data = row['playlistItemData'];
    final videoId = data is Map ? data['videoId'] : null;
    if (videoId is! String || videoId.isEmpty || !seen.add(videoId)) continue;

    final columns = _columns(row['flexColumns'], 'flex');
    final title = columns.isEmpty ? '' : columns.first;
    if (title.isEmpty) continue;

    tracks.add(
      YouTubeSearchSuggestion(
        videoId: videoId,
        displayText: title,
        channelTitle: columns.length > 1 ? columns[1] : '',
        thumbnailUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
        duration: _parseDuration(_columns(row['fixedColumns'], 'fixed').join()),
      ),
    );
  }
  return List.unmodifiable(tracks);
}

Iterable<Map<Object?, Object?>> _collect(Object? node, String key) sync* {
  if (node is List) {
    for (final entry in node) {
      yield* _collect(entry, key);
    }
    return;
  }
  if (node is! Map) return;
  final match = node[key];
  if (match is Map) {
    yield match;
    return;
  }
  for (final value in node.values) {
    yield* _collect(value, key);
  }
}

List<String> _columns(Object? columns, String kind) {
  if (columns is! List) return const [];
  final rendererKey = kind == 'flex'
      ? 'musicResponsiveListItemFlexColumnRenderer'
      : 'musicResponsiveListItemFixedColumnRenderer';
  return [
    for (final column in columns)
      if (column is Map) _runs(column[rendererKey]),
  ];
}

String _runs(Object? renderer) {
  if (renderer is! Map) return '';
  final text = renderer['text'];
  final runs = text is Map ? text['runs'] : null;
  if (runs is! List) return '';
  return runs
      .map((run) => run is Map ? run['text'] : null)
      .whereType<String>()
      .join()
      .trim();
}

Duration? _parseDuration(String value) {
  final parts = value.trim().split(':').map(int.tryParse).toList();
  if (parts.isEmpty || parts.length > 3 || parts.any((p) => p == null)) {
    return null;
  }
  final values = parts.cast<int>();
  final duration = values.length == 3
      ? Duration(hours: values[0], minutes: values[1], seconds: values[2])
      : values.length == 2
      ? Duration(minutes: values[0], seconds: values[1])
      : Duration.zero;
  return duration > Duration.zero ? duration : null;
}
