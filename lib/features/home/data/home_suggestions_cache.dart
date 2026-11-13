import 'dart:convert';

import 'package:flow_music/features/home/data/home_suggestions_repository.dart';
import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

const String homeSuggestionsCacheBoxName = 'home_suggestions_cache';

/// Cuanto vale una tanda de sugerencias antes de pedir otra.
const Duration homeSuggestionsCacheTtl = Duration(hours: 1);

/// Sugerencias guardadas en disco, con la hora en que se pidieron.
class CachedHomeSuggestions {
  const CachedHomeSuggestions({required this.result, required this.savedAt});

  final HomeSuggestionsResult result;
  final DateTime savedAt;

  /// Ya paso su hora: sigue sirviendo para pintar la pantalla al instante, pero
  /// conviene renovarla en segundo plano.
  bool get isStale =>
      DateTime.now().difference(savedAt) >= homeSuggestionsCacheTtl;
}

/// Guarda la ultima tanda de sugerencias del home para que al reabrir la app la
/// pantalla se pinte de inmediato en vez de quedarse cargando.
class HomeSuggestionsCache {
  const HomeSuggestionsCache();

  static const String _key = 'latest';

  /// Null si la caja todavia no esta abierta (p. ej. en tests): la caché es un
  /// atajo, nunca un requisito para que el home funcione.
  Box? get _box => Hive.isBoxOpen(homeSuggestionsCacheBoxName)
      ? Hive.box(homeSuggestionsCacheBoxName)
      : null;

  CachedHomeSuggestions? read() {
    final raw = _box?.get(_key);
    if (raw is! String) return null;
    return decodeCachedHomeSuggestions(raw);
  }

  Future<void> write(HomeSuggestionsResult result) async {
    final box = _box;
    if (box == null || result.suggestions.isEmpty) return;
    try {
      await box.put(
        _key,
        encodeCachedHomeSuggestions(result: result, savedAt: DateTime.now()),
      );
    } catch (error) {
      debugPrint('Home suggestions cache write failed: $error');
    }
  }

  Future<void> clear() async => _box?.delete(_key);
}

/// Serializa la tanda con su hora. Formato propio y minimo (id, titulo, artista,
/// portada, duracion) para no arrastrar la forma de la API de YouTube.
String encodeCachedHomeSuggestions({
  required HomeSuggestionsResult result,
  required DateTime savedAt,
}) {
  return jsonEncode({
    'savedAt': savedAt.toIso8601String(),
    'countryName': result.countryName,
    'suggestions': _encodeList(result.suggestions),
    'chart': _encodeList(result.chart),
    'forYou': _encodeList(result.forYou),
  });
}

List<Map<String, Object?>> _encodeList(List<YouTubeSearchSuggestion> items) {
  return items
      .map(
        (suggestion) => {
          'videoId': suggestion.videoId,
          'title': suggestion.displayText,
          'artist': suggestion.channelTitle,
          'thumbnailUrl': suggestion.thumbnailUrl,
          'durationMs': suggestion.duration?.inMilliseconds,
        },
      )
      .toList(growable: false);
}

List<YouTubeSearchSuggestion> _decodeList(Object? items) {
  if (items is! List) return const [];
  final suggestions = <YouTubeSearchSuggestion>[];
  for (final item in items) {
    if (item is! Map) continue;
    final videoId = item['videoId'];
    final title = item['title'];
    if (videoId is! String || videoId.isEmpty) continue;
    if (title is! String || title.isEmpty) continue;

    final durationMs = item['durationMs'];
    suggestions.add(
      YouTubeSearchSuggestion(
        videoId: videoId,
        displayText: title,
        channelTitle: item['artist'] as String? ?? '',
        thumbnailUrl: item['thumbnailUrl'] as String? ?? '',
        duration: durationMs is int && durationMs > 0
            ? Duration(milliseconds: durationMs)
            : null,
      ),
    );
  }
  return suggestions;
}

/// Lee lo guardado. Devuelve null ante cualquier cosa inesperada: mejor volver a
/// pedir las sugerencias que pintar basura.
CachedHomeSuggestions? decodeCachedHomeSuggestions(String raw) {
  if (raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;

    final savedAtRaw = decoded['savedAt'];
    final savedAt = savedAtRaw is String ? DateTime.tryParse(savedAtRaw) : null;
    if (savedAt == null) return null;

    final suggestions = _decodeList(decoded['suggestions']);
    if (suggestions.isEmpty) return null;

    return CachedHomeSuggestions(
      result: HomeSuggestionsResult(
        suggestions: suggestions,
        countryName: decoded['countryName'] as String?,
        chart: _decodeList(decoded['chart']),
        forYou: _decodeList(decoded['forYou']),
      ),
      savedAt: savedAt,
    );
  } catch (error) {
    debugPrint('Home suggestions cache read failed: $error');
    return null;
  }
}
