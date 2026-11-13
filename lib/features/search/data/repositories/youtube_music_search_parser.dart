import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';

/// Lee la respuesta JSON de la busqueda de YouTube Music (`youtubei/v1/search`
/// en music.youtube.com con el filtro de canciones).
///
/// Cada fila es un `musicResponsiveListItemRenderer`: la primera columna trae
/// el titulo y la segunda «Artista • Album • 3:45».
class YouTubeMusicSearchParser {
  const YouTubeMusicSearchParser();

  static final RegExp _durationPattern = RegExp(r'^\d{1,2}(:\d{2}){1,2}$');

  List<YouTubeSearchSuggestion> parseSuggestions(
    Object? data, {
    int limit = 12,
  }) {
    final suggestions = <YouTubeSearchSuggestion>[];
    final seenVideoIds = <String>{};

    for (final item in _collectItems(data)) {
      final suggestion = _parseItem(item);
      if (suggestion == null || !seenVideoIds.add(suggestion.videoId)) {
        continue;
      }
      suggestions.add(suggestion);
      if (suggestions.length >= limit) break;
    }

    return List.unmodifiable(suggestions);
  }

  Iterable<Map<Object?, Object?>> _collectItems(Object? node) sync* {
    if (node is List) {
      for (final entry in node) {
        yield* _collectItems(entry);
      }
      return;
    }
    if (node is! Map) return;

    final item = node['musicResponsiveListItemRenderer'];
    if (item is Map) {
      yield item;
      return;
    }
    for (final value in node.values) {
      yield* _collectItems(value);
    }
  }

  YouTubeSearchSuggestion? _parseItem(Map<Object?, Object?> item) {
    final videoId = _readVideoId(item);
    final columns = _readColumns(item['flexColumns']);
    final title = columns.isEmpty ? '' : columns.first;
    if (videoId.isEmpty || title.isEmpty) return null;

    final details = columns.length > 1
        ? columns[1].split(' • ').map((part) => part.trim()).toList()
        : const <String>[];
    final duration =
        details.isNotEmpty && _durationPattern.hasMatch(details.last)
        ? _parseDuration(details.last)
        : null;

    return YouTubeSearchSuggestion(
      videoId: videoId,
      displayText: title,
      channelTitle: details.isEmpty ? '' : details.first,
      thumbnailUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
      duration: duration,
    );
  }

  String _readVideoId(Map<Object?, Object?> item) {
    final playlistItemData = item['playlistItemData'];
    if (playlistItemData is Map && playlistItemData['videoId'] is String) {
      return (playlistItemData['videoId'] as String).trim();
    }
    return '';
  }

  List<String> _readColumns(Object? flexColumns) {
    if (flexColumns is! List) return const [];
    return [
      for (final column in flexColumns)
        _readRuns(
          column is Map
              ? column['musicResponsiveListItemFlexColumnRenderer']
              : null,
        ),
    ];
  }

  String _readRuns(Object? renderer) {
    if (renderer is! Map) return '';
    final text = renderer['text'];
    final runs = text is Map ? text['runs'] : null;
    if (runs is! List) return '';
    return runs
        .map((run) => run is Map ? run['text'] : null)
        .whereType<String>()
        .join()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Duration? _parseDuration(String value) {
    final parts = value.split(':').map(int.parse).toList(growable: false);
    final duration = parts.length == 3
        ? Duration(hours: parts[0], minutes: parts[1], seconds: parts[2])
        : Duration(minutes: parts[0], seconds: parts[1]);
    return duration > Duration.zero ? duration : null;
  }
}
