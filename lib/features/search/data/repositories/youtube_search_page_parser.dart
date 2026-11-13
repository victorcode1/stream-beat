import 'dart:convert';

import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';

class YouTubeSearchPageParser {
  const YouTubeSearchPageParser();

  static const Duration _minSongDuration = Duration(minutes: 1);
  static const Duration _maxSongDuration = Duration(minutes: 12);

  static const List<String> _initialDataMarkers = [
    'var ytInitialData = ',
    'window["ytInitialData"] = ',
    'ytInitialData = ',
  ];

  List<YouTubeSearchSuggestion> parseSuggestions(
    String html, {
    int limit = 12,
  }) {
    return parseSuggestionsFromData(_extractInitialData(html), limit: limit);
  }

  /// Igual que [parseSuggestions], pero sobre el JSON ya decodificado (la
  /// respuesta de la API `youtubei/v1/search`). Por defecto conserva el filtro
  /// de 1 a 12 minutos que usa el autoplay; la busqueda del usuario lo relaja.
  List<YouTubeSearchSuggestion> parseSuggestionsFromData(
    Object? data, {
    int limit = 12,
    Duration? minDuration = _minSongDuration,
    Duration? maxDuration = _maxSongDuration,
  }) {
    final suggestions = <YouTubeSearchSuggestion>[];
    final seenVideoIds = <String>{};

    for (final renderer in _collectVideoRenderers(data)) {
      final suggestion = _parseSuggestion(
        renderer,
        minDuration: minDuration,
        maxDuration: maxDuration,
      );
      if (suggestion == null) {
        continue;
      }
      if (!seenVideoIds.add(suggestion.videoId)) {
        continue;
      }
      suggestions.add(suggestion);
      if (suggestions.length >= limit) {
        break;
      }
    }

    return List.unmodifiable(suggestions);
  }

  Map<String, dynamic> _extractInitialData(String html) {
    for (final marker in _initialDataMarkers) {
      final markerIndex = html.indexOf(marker);
      if (markerIndex < 0) {
        continue;
      }

      final startIndex = html.indexOf('{', markerIndex + marker.length);
      if (startIndex < 0) {
        continue;
      }

      final jsonSource = _extractBalancedJson(html, startIndex);
      final decoded = jsonDecode(jsonSource);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    }

    throw const FormatException('Could not find ytInitialData in page.');
  }

  String _extractBalancedJson(String source, int startIndex) {
    var depth = 0;
    var isInsideString = false;
    var isEscaped = false;

    for (var index = startIndex; index < source.length; index++) {
      final char = source[index];

      if (isInsideString) {
        if (isEscaped) {
          isEscaped = false;
          continue;
        }
        if (char == r'\') {
          isEscaped = true;
          continue;
        }
        if (char == '"') {
          isInsideString = false;
        }
        continue;
      }

      if (char == '"') {
        isInsideString = true;
        continue;
      }

      if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) {
          return source.substring(startIndex, index + 1);
        }
      }
    }

    throw const FormatException('Could not extract ytInitialData JSON.');
  }

  Iterable<Map<String, dynamic>> _collectVideoRenderers(Object? node) sync* {
    if (node is List) {
      for (final entry in node) {
        yield* _collectVideoRenderers(entry);
      }
      return;
    }

    if (node is! Map) {
      return;
    }

    final typedNode = Map<String, dynamic>.from(node);
    final renderer = typedNode['videoRenderer'];
    if (renderer is Map) {
      yield Map<String, dynamic>.from(renderer);
    }

    for (final value in typedNode.values) {
      yield* _collectVideoRenderers(value);
    }
  }

  YouTubeSearchSuggestion? _parseSuggestion(
    Map<String, dynamic> renderer, {
    Duration? minDuration,
    Duration? maxDuration,
  }) {
    final videoId = _readString(renderer['videoId']);
    final displayText = _normalizeText(_readText(renderer['title']));
    final ownerText = _normalizeText(_readText(renderer['ownerText']));
    final channelTitle = ownerText.isNotEmpty
        ? ownerText
        : _normalizeText(_readText(renderer['longBylineText']));
    final thumbnailUrl = _readThumbnailUrl(renderer['thumbnail']);
    final duration = _parseDurationText(_readText(renderer['lengthText']));

    if (videoId.isEmpty || displayText.isEmpty) {
      return null;
    }

    if (duration != null &&
        ((minDuration != null && duration < minDuration) ||
            (maxDuration != null && duration > maxDuration))) {
      return null;
    }

    return YouTubeSearchSuggestion(
      videoId: videoId,
      displayText: displayText,
      channelTitle: channelTitle,
      thumbnailUrl: thumbnailUrl,
      duration: duration,
    );
  }

  String _readThumbnailUrl(Object? node) {
    if (node is! Map) {
      return '';
    }

    final thumbnails = node['thumbnails'];
    if (thumbnails is! List) {
      return '';
    }

    for (final entry in thumbnails.reversed) {
      if (entry is! Map) {
        continue;
      }
      final url = _readString(entry['url']);
      if (url.isNotEmpty) {
        return url.startsWith('//') ? 'https:$url' : url;
      }
    }

    return '';
  }

  String _readText(Object? node) {
    if (node == null) {
      return '';
    }
    if (node is String) {
      return node;
    }
    if (node is List) {
      return _normalizeText(
        node.map(_readText).where((text) => text.trim().isNotEmpty).join(),
      );
    }
    if (node is! Map) {
      return '';
    }

    final simpleText = _readInlineText(node['simpleText']);
    if (simpleText.trim().isNotEmpty) {
      return simpleText;
    }

    final text = _readInlineText(node['text']);
    if (text.trim().isNotEmpty) {
      return text;
    }

    final content = _readInlineText(node['content']);
    if (content.trim().isNotEmpty) {
      return content;
    }

    final runs = node['runs'];
    if (runs is List) {
      final value = runs
          .map(_readText)
          .where((text) => text.trim().isNotEmpty)
          .join();
      if (value.isNotEmpty) {
        return _normalizeText(value);
      }
    }

    return '';
  }

  String _normalizeText(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Duration? _parseDurationText(String value) {
    final parts = value
        .trim()
        .split(':')
        .map((part) => int.tryParse(part))
        .toList(growable: false);
    if (parts.isEmpty || parts.any((part) => part == null)) return null;

    final values = parts.cast<int>();
    final duration = switch (values.length) {
      2 => Duration(minutes: values[0], seconds: values[1]),
      3 => Duration(hours: values[0], minutes: values[1], seconds: values[2]),
      _ => Duration.zero,
    };
    return duration > Duration.zero ? duration : null;
  }

  String _readString(Object? value) {
    if (value is String) {
      return value.trim();
    }
    return '';
  }

  String _readInlineText(Object? value) {
    if (value is String) {
      return value;
    }
    return '';
  }
}
