import 'dart:convert';

import 'package:flow_music/features/autoplay/data/resolved_audio.dart';
import 'package:flow_music/features/autoplay/data/shared_youtube_client.dart';
import 'package:flow_music/features/autoplay/data/youtube_playback_stream.dart';
import 'package:flow_music/features/autoplay/data/youtube_access_state.dart';
import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/features/search/data/repositories/piped_video_duration.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const _pipedApiBaseUrl = 'https://api.piped.private.coffee';

Future<ResolvedAudio?> resolveAudioFor(
  YouTubeSearchSuggestion suggestion,
) async {
  final videoId = suggestion.videoId;
  if (videoId.isEmpty) return null;

  try {
    // Con la IP marcada por YouTube, insistir solo alarga el castigo: se va
    // directo a Piped hasta que pase el enfriamiento.
    if (!kIsWeb && !isYoutubeRateLimited) {
      final resolved = await _tryResolveViaYoutubeExplode(suggestion);
      if (resolved != null) return resolved;
    }

    return await _resolveViaPiped(suggestion);
  } catch (error, stackTrace) {
    debugPrint('Failed to prefetch ${suggestion.videoId}: $error');
    debugPrint('$stackTrace');
    return null;
  }
}

Future<ResolvedAudio?> _tryResolveViaYoutubeExplode(
  YouTubeSearchSuggestion suggestion,
) async {
  try {
    return await _resolveViaYoutubeExplode(suggestion);
  } catch (error, stackTrace) {
    final rateLimited = reportYoutubeFailure(error);
    debugPrint(
      'youtube_explode prefetch failed for ${suggestion.videoId}, falling back to Piped: $error',
    );
    if (!rateLimited) debugPrint('$stackTrace');
    return null;
  }
}

Future<ResolvedAudio?> _resolveViaYoutubeExplode(
  YouTubeSearchSuggestion suggestion,
) async {
  // El manifiesto ya trae la duracion en el parametro `dur` de la URL, y la
  // sugerencia suele traerla tambien: pedir ademas los metadatos del video
  // duplicaba la espera de cada pista precargada.
  final manifest = await sharedYoutubeExplode.videos.streamsClient.getManifest(
    suggestion.videoId,
  );
  final playbackStream = pickYoutubePlaybackStream(
    manifest,
    preferMuxed: _isApplePlatform,
  );
  if (playbackStream == null) return null;

  return ResolvedAudio(
    suggestion: suggestion,
    audioUrl: playbackStream.url.toString(),
    mimeType: '${playbackStream.codec.type}/${playbackStream.codec.subtype}',
    requestHeaders: YoutubeHttpClient.defaultHeaders,
    rangeEnd: playbackStream.size.totalBytes - 1,
    fileExtension: playbackStream.container.name,
    title: suggestion.displayText,
    author: suggestion.channelTitle,
    thumbnailUrl: suggestion.thumbnailUrl,
    duration: _resolveAudioDuration(
      streamUri: playbackStream.url,
      knownDuration: suggestion.duration,
    ),
  );
}

bool get _isApplePlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

Future<ResolvedAudio?> _resolveViaPiped(
  YouTubeSearchSuggestion suggestion,
) async {
  final uri = Uri.parse('$_pipedApiBaseUrl/streams/${suggestion.videoId}');
  final response = await http.get(uri);
  if (response.statusCode < 200 || response.statusCode >= 300) return null;

  final decoded = jsonDecode(response.body);
  if (decoded is! Map<String, dynamic>) return null;

  final streams = decoded['audioStreams'];
  if (streams is! List || streams.isEmpty) return null;

  final typed = streams
      .whereType<Map>()
      .map((stream) => Map<String, dynamic>.from(stream))
      .where((stream) => (stream['url'] as String? ?? '').isNotEmpty)
      .toList();
  if (typed.isEmpty) return null;

  typed.sort((a, b) {
    if (_isApplePlatform) {
      final aM4a = _isM4aStream(a) ? 1 : 0;
      final bM4a = _isM4aStream(b) ? 1 : 0;
      if (aM4a != bM4a) return bM4a.compareTo(aM4a);
    }
    final aOpus = a['format'] == 'WEBMA_OPUS' ? 1 : 0;
    final bOpus = b['format'] == 'WEBMA_OPUS' ? 1 : 0;
    if (aOpus != bOpus) return bOpus.compareTo(aOpus);
    final aBitrate = a['bitrate'] as int? ?? 0;
    final bBitrate = b['bitrate'] as int? ?? 0;
    return bBitrate.compareTo(aBitrate);
  });

  final stream = typed.first;
  return ResolvedAudio(
    suggestion: suggestion,
    audioUrl: stream['url'] as String,
    mimeType: stream['mimeType'] as String? ?? 'audio/webm',
    title: decoded['title'] as String? ?? suggestion.displayText,
    author: decoded['uploader'] as String? ?? suggestion.channelTitle,
    thumbnailUrl: 'https://i.ytimg.com/vi/${suggestion.videoId}/hqdefault.jpg',
    duration: suggestion.duration ?? parsePipedDuration(decoded['duration']),
  );
}

bool _isM4aStream(Map<String, dynamic> stream) {
  final format = (stream['format'] as String? ?? '').toUpperCase();
  final mimeType = (stream['mimeType'] as String? ?? '').toLowerCase();
  return format.contains('M4A') || mimeType.contains('mp4');
}

Duration? _resolveAudioDuration({
  required Uri streamUri,
  Duration? knownDuration,
  Duration? fallback,
}) {
  final canonical = knownDuration ?? fallback;
  if (canonical != null && canonical > Duration.zero) {
    return canonical;
  }
  return _parseStreamDuration(streamUri);
}

Duration? _parseStreamDuration(Uri uri) {
  final rawDuration = uri.queryParameters['dur'];
  if (rawDuration == null || rawDuration.isEmpty) return null;

  final seconds = double.tryParse(rawDuration);
  if (seconds == null || !seconds.isFinite || seconds <= 0) return null;

  return Duration(milliseconds: (seconds * 1000).round());
}
