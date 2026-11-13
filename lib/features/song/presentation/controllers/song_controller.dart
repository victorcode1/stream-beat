import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:audioplayers/audioplayers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/audio/background_audio_handler.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/core/utils/main_controller.dart';
import 'package:flow_music/features/autoplay/data/audio_cache_stub.dart'
    if (dart.library.io) 'package:flow_music/features/autoplay/data/audio_cache_io.dart';
import 'package:flow_music/features/autoplay/data/resolved_audio.dart';
import 'package:flow_music/features/autoplay/data/shared_youtube_client.dart';
import 'package:flow_music/features/autoplay/data/youtube_access_state.dart';
import 'package:flow_music/features/autoplay/data/youtube_playback_stream.dart';
import 'package:flow_music/features/autoplay/presentation/controllers/autoplay_queue_controller.dart';
import 'package:flow_music/features/history/presentation/controllers/playback_history_controller.dart';
import 'package:flow_music/features/library/data/downloaded_audio.dart';
import 'package:flow_music/features/offline/data/offline_audio_store_stub.dart'
    if (dart.library.io) 'package:flow_music/features/offline/data/offline_audio_store_io.dart';
import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/features/settings/presentation/controllers/autoplay_enabled_controller.dart';
import 'package:flow_music/features/settings/presentation/controllers/audio_download_quality_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'audio_download_writer_stub.dart'
    if (dart.library.io) 'audio_download_writer_io.dart';
import 'local_video_controller_stub.dart'
    if (dart.library.io) 'local_video_controller_io.dart';
import 'video_completion_guard.dart';

final songController = ChangeNotifierProvider<SongController>((ref) {
  return SongController(ref: ref);
});

enum PlaybackMode { audio, video }

const _pipedApiBaseUrl = 'https://api.piped.private.coffee';

/// Los streams solo de audio de googlevideo responden 403 a rangos de mas de
/// ~1 MB, y los reproductores nativos (AVPlayer, MediaPlayer) piden el archivo
/// entero. El stream combinado (itag 18) acepta rangos abiertos, asi que las
/// apps nativas lo prefieren; la web usa el reproductor embebido.
bool get _prefersMuxedStream =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.android);

bool get _isApplePlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

class _PipedStreamInfo {
  const _PipedStreamInfo({
    required this.title,
    required this.uploader,
    required this.thumbnailUrl,
    required this.audioUrl,
    required this.audioMimeType,
    required this.videoUrl,
  });

  final String title;
  final String uploader;
  final String thumbnailUrl;
  final String? audioUrl;
  final String? audioMimeType;
  final String? videoUrl;
}

class _PipedAudioStream {
  const _PipedAudioStream({required this.url, required this.mimeType});

  final String url;
  final String mimeType;
}

/// Un stream de audio de Piped elegido para guardar a disco.
class _PipedDownloadStream {
  const _PipedDownloadStream({
    required this.url,
    required this.mimeType,
    required this.contentLength,
  });

  final String url;
  final String mimeType;

  /// 0 cuando Piped no lo anota: el escritor simplemente no reporta progreso.
  final int contentLength;
}

/// Bytes y metadatos listos para escribir a disco, sin importar de que fuente
/// salieron (youtube_explode o Piped).
class _AudioDownloadSource {
  const _AudioDownloadSource({
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.extension,
    required this.totalBytes,
    required this.chunks,
    required this.dispose,
    this.hasVideoTrack = false,
  });

  final String title;
  final String author;
  final String thumbnailUrl;
  final String extension;
  final int totalBytes;
  final Stream<List<int>> chunks;
  final bool hasVideoTrack;

  /// Cierra el cliente que abrio el stream. Se llama una vez escrito el archivo
  /// (o si algo falla), nunca antes: los bytes siguen viniendo de ahi.
  final void Function() dispose;
}

/// Extension de archivo para lo que sirve Piped.
String _downloadExtensionFor(String mimeType) {
  final normalized = mimeType.toLowerCase();
  if (normalized.contains('mp4') || normalized.contains('m4a')) return 'm4a';
  if (normalized.contains('webm') || normalized.contains('opus')) return 'webm';
  if (normalized.contains('mpeg')) return 'mp3';
  return 'm4a';
}

Duration? _resolveAudioDuration({
  required Uri streamUri,
  Duration? knownDuration,
  Duration? fallback,
}) {
  final videoDuration = knownDuration ?? fallback;
  if (videoDuration != null && videoDuration > Duration.zero) {
    final streamDuration = _parseStreamDuration(streamUri);
    if (streamDuration != null && streamDuration > Duration.zero) {
      final difference = streamDuration - videoDuration;
      final drift = difference.isNegative ? -difference : difference;
      if (drift > const Duration(seconds: 3)) {
        debugPrint(
          'Ignoring stream duration $streamDuration; video metadata duration is $videoDuration.',
        );
      }
    }
    return videoDuration;
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

AudioOnlyStreamInfo _pickAudioForQuality(
  List<AudioOnlyStreamInfo> pool,
  AudioDownloadQuality quality,
) {
  if (pool.isEmpty) {
    throw StateError(LocaleKeys.no_audio_streams.tr());
  }
  final sorted = [
    ...pool,
  ]..sort((a, b) => a.bitrate.bitsPerSecond.compareTo(b.bitrate.bitsPerSecond));
  return switch (quality) {
    AudioDownloadQuality.low => sorted.first,
    AudioDownloadQuality.high => sorted.last,
    AudioDownloadQuality.medium => sorted[sorted.length ~/ 2],
  };
}

class SongController extends ChangeNotifier {
  Ref ref;
  VideoPlayerController? _videoPlayerController;

  /// Wired by the app coordinator so video and audio completion follow the
  /// same repeat/autoplay policy.
  Future<void> Function()? onVideoComplete;

  PlaybackMode _currentMode = PlaybackMode.audio;
  bool _isLoading = false;
  bool _isDownloading = false;
  bool _isSavingOffline = false;
  double _downloadProgress = 0;
  double _offlineProgress = 0;
  String? _currentVideoId;
  Video? _videoInfo;
  String? _webVideoTitle;
  String? _webVideoAuthor;
  String? _webVideoThumbnailUrl;
  String? _webEmbedVideoId;
  DownloadedAudio? _downloadedAudio;
  DownloadedAudio? _downloadedVideo;
  DownloadedAudio? _offlineAudio;
  bool _isPlayingDownloadedAudio = false;
  bool _isPlayingDownloadedVideo = false;
  bool _isPlayingOfflineAudio = false;

  /// Cada seleccion invalida todo el trabajo asincrono de las selecciones
  /// anteriores. La resolucion de YouTube/Piped puede tardar varios segundos en
  /// una red movil y completar fuera de orden; sin esta compuerta, una cancion
  /// vieja terminaba reemplazando a la ultima que el usuario habia tocado.
  int _playbackGeneration = 0;

  PlaybackMode get currentMode => _currentMode;
  bool get isLoading => _isLoading;
  bool get isDownloading => _isDownloading;
  bool get isSavingOffline => _isSavingOffline;
  double get downloadProgress => _downloadProgress;
  double get offlineProgress => _offlineProgress;
  VideoPlayerController? get videoPlayerController => _videoPlayerController;
  Video? get videoInfo => _videoInfo;
  String? get currentVideoId => _currentVideoId;
  String? get webEmbedVideoId => _webEmbedVideoId;
  FlowAudioHandler get _audioHandler => flowAudioHandler;
  AudioPlayer get _audioPlayer => _audioHandler.player;
  AudioPlayer get audioPlayer => _audioPlayer;
  DownloadedAudio? get _currentDownloadedAudio {
    final downloadedAudio = _downloadedAudio;
    if (downloadedAudio == null) return null;
    if (downloadedAudio.videoId.isEmpty) {
      return _isPlayingDownloadedAudio ? downloadedAudio : null;
    }
    return downloadedAudio.videoId == _currentVideoId ? downloadedAudio : null;
  }

  DownloadedAudio? get _currentDownloadedVideo {
    final downloadedVideo = _downloadedVideo;
    if (downloadedVideo == null) return null;
    if (downloadedVideo.videoId.isEmpty) {
      return _isPlayingDownloadedVideo ? downloadedVideo : null;
    }
    return downloadedVideo.videoId == _currentVideoId ? downloadedVideo : null;
  }

  DownloadedAudio? get _currentDownloadedMedia {
    return _currentMode == PlaybackMode.video
        ? _currentDownloadedVideo
        : _currentDownloadedAudio;
  }

  DownloadedAudio? get _currentOfflineAudio {
    final offlineAudio = _offlineAudio;
    if (offlineAudio == null) return null;
    if (offlineAudio.videoId.isEmpty) {
      return _isPlayingOfflineAudio ? offlineAudio : null;
    }
    return offlineAudio.videoId == _currentVideoId ? offlineAudio : null;
  }

  String? get downloadedFilePath => _currentDownloadedAudio?.filePath;
  DownloadedAudio? get currentDownloadedMedia => _currentDownloadedMedia;
  DownloadedAudio? get currentDownloadedAudio => _currentDownloadedAudio;
  DownloadedAudio? get currentOfflineAudio => _currentOfflineAudio;
  bool get hasDownloadedCurrentAudio => _currentDownloadedAudio != null;
  bool get hasDownloadedCurrentVideo => _currentDownloadedVideo != null;
  bool get hasDownloadedCurrentMedia => _currentDownloadedMedia != null;
  bool get hasOfflineCurrentAudio => _currentOfflineAudio != null;
  String? get displayTitle =>
      _currentOfflineAudio?.title ??
      _currentDownloadedMedia?.title ??
      _videoInfo?.title ??
      _webVideoTitle;
  String? get displayAuthor =>
      _currentOfflineAudio?.author ??
      _currentDownloadedMedia?.author ??
      _videoInfo?.author ??
      _webVideoAuthor;
  String? get displayThumbnailUrl =>
      _currentOfflineAudio?.thumbnailUrl ??
      _currentDownloadedMedia?.thumbnailUrl ??
      _videoInfo?.thumbnails.highResUrl ??
      _webVideoThumbnailUrl;
  DownloadedAudio? get currentPlaylistItem {
    final downloadedMedia = _currentDownloadedMedia;
    if (downloadedMedia != null) return downloadedMedia;

    final videoId = _currentVideoId;
    if (videoId == null || videoId.isEmpty) return null;

    return DownloadedAudio(
      videoId: videoId,
      title: displayTitle ?? '',
      author: displayAuthor ?? '',
      thumbnailUrl: displayThumbnailUrl ?? '',
      filePath: '',
      downloadedAt: DateTime.now(),
      mediaType: _currentMode == PlaybackMode.video
          ? DownloadedMediaType.video
          : DownloadedMediaType.audio,
    );
  }

  SongController({required this.ref});

  int _beginPlaybackRequest() {
    _playbackFailed = false;
    return ++_playbackGeneration;
  }

  /// La ultima peticion de reproduccion termino en error y no sono nada.
  /// El autoplay lo usa para saltar a la siguiente cancion.
  bool get playbackFailed => _playbackFailed;
  bool _playbackFailed = false;

  bool _isCurrentPlaybackRequest(int generation) {
    return generation == _playbackGeneration;
  }

  void _invalidatePlaybackRequests() {
    _playbackGeneration++;
  }

  /// Tear down the current song playback so a different audio source
  /// (e.g. a radio station) can take over the global audio handler without
  /// the previous video player keeping its own audio track alive in the
  /// background. Without this, starting a radio while a YouTube video plays
  /// leaves the video's audio overlapping the radio stream.
  Future<void> clearSongPlayback() async {
    _invalidatePlaybackRequests();
    try {
      await _audioHandler.stop();
    } catch (error) {
      debugPrint('Could not interrupt previous audio source: $error');
    }
    final video = _videoPlayerController;
    _videoPlayerController = null;
    if (video != null) {
      try {
        await video.pause();
      } catch (_) {}
      try {
        await video.dispose();
      } catch (_) {}
    }
    _currentVideoId = null;
    _videoInfo = null;
    _webVideoTitle = null;
    _webVideoAuthor = null;
    _webVideoThumbnailUrl = null;
    _webEmbedVideoId = null;
    _downloadedAudio = null;
    _downloadedVideo = null;
    _offlineAudio = null;
    _isPlayingDownloadedAudio = false;
    _isPlayingDownloadedVideo = false;
    _isPlayingOfflineAudio = false;
    _isLoading = false;
    notifyListeners();
  }

  /// Seed the title / author / thumbnail before the real metadata fetch
  /// resolves. Lets the player UI show the correct song name immediately
  /// (e.g. when tapping a history entry) instead of falling back to the
  /// raw videoId during the loading window.
  void preloadMetadata({
    required String videoId,
    String? title,
    String? author,
    String? thumbnailUrl,
  }) {
    if (videoId.isEmpty) return;
    // La pantalla que se abre a continuacion inicia y espera el cambio de
    // fuente. Lanzar aqui otro `stop()` sin esperarlo puede completarse tarde y
    // detener la cancion nueva justo despues de que empiece.
    _invalidatePlaybackRequests();
    _currentVideoId = videoId;
    _videoInfo = null;
    _webVideoTitle = (title != null && title.isNotEmpty) ? title : null;
    _webVideoAuthor = author;
    _webVideoThumbnailUrl = (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
        ? thumbnailUrl
        : null;
    notifyListeners();
  }

  Future<void> autoPlay({required String id, Duration? knownDuration}) async {
    if (_currentMode == PlaybackMode.audio) {
      await playAudio(id: id, knownDuration: knownDuration);
    } else {
      await playVideo(id: id);
    }
  }

  /// Start playback from an already-resolved audio stream, skipping the
  /// Piped / youtube_explode_dart resolution step. Used by the autoplay queue
  /// when advancing to the next prefetched track.
  Future<void> playPrefetched(ResolvedAudio resolved) async {
    final generation = _beginPlaybackRequest();
    try {
      _isLoading = true;
      _currentMode = PlaybackMode.audio;
      _currentVideoId = resolved.videoId;
      _isPlayingDownloadedAudio = false;
      _isPlayingDownloadedVideo = false;
      _isPlayingOfflineAudio = false;
      _videoInfo = null;
      _webEmbedVideoId = kIsWeb ? resolved.videoId : null;
      _webVideoTitle = resolved.title;
      _webVideoAuthor = resolved.author;
      _webVideoThumbnailUrl = resolved.thumbnailUrl;
      notifyListeners();

      await _audioHandler.stop();
      if (!_isCurrentPlaybackRequest(generation)) return;
      await _videoPlayerController?.pause();
      if (!_isCurrentPlaybackRequest(generation)) return;

      final localCopies = await Future.wait<DownloadedAudio?>([
        getDownloadedAudio(resolved.videoId),
        getOfflineAudio(resolved.videoId),
      ]);
      if (!_isCurrentPlaybackRequest(generation)) return;
      _downloadedAudio = localCopies[0];
      _offlineAudio = localCopies[1];

      await _videoPlayerController?.dispose();
      if (!_isCurrentPlaybackRequest(generation)) return;
      _videoPlayerController = null;

      final offlineAudio = _currentOfflineAudio;
      final cachedPrefetchPath =
          resolved.cacheFilePath ?? await cachedAudioPath(resolved.videoId);
      if (!_isCurrentPlaybackRequest(generation)) return;
      final cachePath = offlineAudio?.filePath ?? cachedPrefetchPath;
      if (cachePath != null && cachePath.isNotEmpty) {
        _isPlayingOfflineAudio = offlineAudio != null;
        await _audioHandler.playFile(
          filePath: cachePath,
          id: resolved.videoId,
          title:
              offlineAudio?.title ??
              resolved.title ??
              resolved.suggestion.displayText,
          artist:
              offlineAudio?.author ??
              resolved.author ??
              resolved.suggestion.channelTitle,
          artUrl:
              offlineAudio?.thumbnailUrl ??
              resolved.thumbnailUrl ??
              resolved.suggestion.thumbnailUrl,
          canonicalDuration: resolved.duration,
        );
      } else {
        // Stale googlevideo URLs hang setSourceUrl for ~30s before throwing.
        // Re-resolve fresh instead so the UI doesn't freeze.
        if (resolved.isUrlExpired) {
          debugPrint(
            'Prefetched URL for ${resolved.videoId} is expired, re-resolving',
          );
          if (!_isCurrentPlaybackRequest(generation)) return;
          await playAudio(id: resolved.videoId);
          return;
        }
        await _audioHandler.playUrl(
          url: resolved.audioUrl,
          id: resolved.videoId,
          title: resolved.title ?? resolved.suggestion.displayText,
          artist: resolved.author ?? resolved.suggestion.channelTitle,
          artUrl: resolved.thumbnailUrl ?? resolved.suggestion.thumbnailUrl,
          mimeType: resolved.mimeType,
          canonicalDuration: resolved.duration,
          requestHeaders: resolved.requestHeaders,
          proxyRemoteSource: _isApplePlatform,
          sourceContentLength: resolved.rangeEnd == null
              ? null
              : resolved.rangeEnd! + 1,
        );
      }

      if (!_isCurrentPlaybackRequest(generation)) return;
      _isLoading = false;
      _ensureAutoplayQueueForCurrent(resolved.videoId);
      unawaited(
        ref
            .read(playbackHistoryControllerProvider.notifier)
            .recordSong(
              videoId: resolved.videoId,
              title: resolved.title ?? resolved.suggestion.displayText,
              author: resolved.author ?? resolved.suggestion.channelTitle,
              thumbnailUrl:
                  resolved.thumbnailUrl ?? resolved.suggestion.thumbnailUrl,
            ),
      );
      notifyListeners();
    } catch (e, stackTrace) {
      if (!_isCurrentPlaybackRequest(generation)) return;
      debugPrint('Error playing prefetched audio: $e');
      debugPrint('$stackTrace');
      _isLoading = false;
      notifyListeners();
      // Fall back to the regular resolution path so the user still gets audio.
      await playAudio(id: resolved.videoId);
    }
  }

  Future<void> playAudio({required String id, Duration? knownDuration}) async {
    final generation = _beginPlaybackRequest();
    try {
      _isLoading = true;
      _currentMode = PlaybackMode.audio;

      final extracted = extractVideoId(id);
      final videoId = extracted ?? id;
      _currentVideoId = videoId;
      _isPlayingDownloadedAudio = false;
      _isPlayingDownloadedVideo = false;
      _isPlayingOfflineAudio = false;
      notifyListeners();

      // Corta de inmediato lo que estaba sonando. Tambien invalida cualquier
      // preparacion nativa anterior dentro del handler.
      await _audioHandler.stop();
      if (!_isCurrentPlaybackRequest(generation)) return;
      await _videoPlayerController?.pause();
      if (!_isCurrentPlaybackRequest(generation)) return;

      final localCopies = await Future.wait<DownloadedAudio?>([
        getDownloadedAudio(videoId),
        getOfflineAudio(videoId),
      ]);
      if (!_isCurrentPlaybackRequest(generation)) return;
      _downloadedAudio = localCopies[0];
      _offlineAudio = localCopies[1];

      debugPrint('Attempting to play YouTube audio: $videoId');
      if (kIsWeb) {
        await _playYoutubeEmbed(videoId, generation);
        return;
      }
      _webEmbedVideoId = null;

      final localAudio = _currentOfflineAudio ?? _currentDownloadedAudio;
      if (localAudio != null) {
        await _playLocalAudio(localAudio, generation);
        return;
      }

      // Dispose video player if exists
      await _videoPlayerController?.dispose();
      if (!_isCurrentPlaybackRequest(generation)) return;
      _videoPlayerController = null;

      try {
        // Metadatos y manifiesto en paralelo con el cliente compartido: en
        // serie y con un cliente nuevo tardaban unos 3 s antes de sonar.
        final yt = sharedYoutubeExplode;
        // Los metadatos son opcionales: YouTube a veces responde la pagina
        // del video como "no disponible" aunque el audio si se pueda sacar.
        final videoInfoFuture = yt.videos
            .get(videoId)
            .then<Video?>(
              (video) => video,
              onError: (Object error) {
                debugPrint('YouTube metadata failed for $videoId: $error');
                return null;
              },
            );
        final manifest = await yt.videos.streamsClient.getManifest(videoId);
        final videoInfo = await videoInfoFuture;
        if (!_isCurrentPlaybackRequest(generation)) return;
        _videoInfo = videoInfo;
        final playbackStream = pickYoutubePlaybackStream(
          manifest,
          preferMuxed: _prefersMuxedStream,
        );
        if (playbackStream == null) {
          throw StateError('No audio streams available for video: $videoId');
        }

        final audioUri = playbackStream.url;
        final audioUrl = audioUri.toString();
        final audioMimeType =
            '${playbackStream.codec.type}/${playbackStream.codec.subtype}';
        final canonicalDuration = _resolveAudioDuration(
          streamUri: audioUri,
          knownDuration: knownDuration,
          fallback: _videoInfo?.duration,
        );
        debugPrint(
          'Resolved YouTube ${playbackStream is MuxedStreamInfo ? 'muxed' : 'audio-only'} '
          'stream for $videoId ($audioMimeType)',
        );

        await _audioHandler.playUrl(
          url: audioUrl,
          id: videoId,
          title: _videoInfo?.title ?? videoId,
          artist: _videoInfo?.author ?? '',
          artUrl: _videoInfo?.thumbnails.highResUrl,
          mimeType: audioMimeType,
          canonicalDuration: canonicalDuration,
          requestHeaders: YoutubeHttpClient.defaultHeaders,
          proxyRemoteSource: _isApplePlatform,
          sourceContentLength: playbackStream.size.totalBytes,
        );
        if (!_isCurrentPlaybackRequest(generation)) return;
        debugPrint('Audio player started');
      } catch (error, stackTrace) {
        if (!_isCurrentPlaybackRequest(generation)) return;
        debugPrint(
          'Primary YouTube audio failed for $videoId, trying Piped fallback: $error',
        );
        debugPrint('Stack trace: $stackTrace');
        final fallbackStarted = await _tryPlayPipedAudioFallback(
          videoId: videoId,
          knownDuration: knownDuration,
          fallbackDuration: _videoInfo?.duration,
          generation: generation,
        );
        if (!fallbackStarted) rethrow;
        debugPrint('Audio player started via Piped fallback');
      }

      if (!_isCurrentPlaybackRequest(generation)) return;
      _isLoading = false;
      unawaited(_recordCurrentSong(videoId));
      notifyListeners();
    } catch (e, stackTrace) {
      if (!_isCurrentPlaybackRequest(generation)) return;
      debugPrint('Error playing YouTube audio: $e');
      debugPrint('Stack trace: $stackTrace');
      _playbackFailed = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> playVideo({required String id}) async {
    final generation = _beginPlaybackRequest();
    try {
      _isLoading = true;

      final extracted = extractVideoId(id);
      final videoId = extracted ?? id;
      _currentVideoId = videoId;
      _currentMode = PlaybackMode.video;
      _isPlayingDownloadedAudio = false;
      _isPlayingDownloadedVideo = false;
      _isPlayingOfflineAudio = false;
      notifyListeners();

      await _audioHandler.stop();
      if (!_isCurrentPlaybackRequest(generation)) return;
      await _videoPlayerController?.pause();
      if (!_isCurrentPlaybackRequest(generation)) return;

      final localCopies = await Future.wait<DownloadedAudio?>([
        getDownloadedVideo(videoId),
        getDownloadedAudio(videoId),
        getOfflineAudio(videoId),
      ]);
      if (!_isCurrentPlaybackRequest(generation)) return;
      _downloadedVideo = localCopies[0];
      _downloadedAudio = localCopies[1];
      _offlineAudio = localCopies[2];

      debugPrint('Attempting to play YouTube video: $videoId');
      if (kIsWeb) {
        await _playYoutubeEmbed(videoId, generation);
        return;
      }
      _webEmbedVideoId = null;

      final yt = YoutubeExplode();
      late final String videoUrl;
      try {
        // Get video info
        final videoInfo = await yt.videos.get(videoId);
        if (!_isCurrentPlaybackRequest(generation)) return;
        _videoInfo = videoInfo;

        final manifest = await yt.videos.streamsClient.getManifest(videoId);
        if (!_isCurrentPlaybackRequest(generation)) return;

        // Get video and audio streams
        videoUrl = manifest.muxed.withHighestBitrate().url.toString();
      } finally {
        yt.close();
      }

      log('Got video URL: $videoUrl');

      // Pause audio player
      await _audioPlayer.pause();
      if (!_isCurrentPlaybackRequest(generation)) return;

      // Dispose old video controller if exists
      try {
        await _videoPlayerController?.dispose();
        if (!_isCurrentPlaybackRequest(generation)) return;
        _videoPlayerController = null;
      } catch (e) {
        debugPrint('Error disposing previous video controller: $e');
      }

      // Initialize new video player
      VideoPlayerController? nextVideoController;
      try {
        nextVideoController = VideoPlayerController.networkUrl(
          Uri.parse(videoUrl),
        );

        await nextVideoController.initialize();
        if (!_isCurrentPlaybackRequest(generation)) {
          await nextVideoController.dispose();
          return;
        }
        final activeVideoController = nextVideoController;
        _videoPlayerController = activeVideoController;

        _attachVideoPlayerListeners(activeVideoController, generation);

        await activeVideoController.play();
        if (!_isCurrentPlaybackRequest(generation)) {
          if (identical(_videoPlayerController, activeVideoController)) {
            _videoPlayerController = null;
          }
          await activeVideoController.dispose();
          return;
        }

        debugPrint('Video player started successfully');
      } catch (videoError) {
        if (identical(_videoPlayerController, nextVideoController)) {
          _videoPlayerController = null;
        }
        try {
          await nextVideoController?.dispose();
        } catch (_) {}
        if (!_isCurrentPlaybackRequest(generation)) return;
        debugPrint('Failed to initialize video player: $videoError');

        // Fallback to audio mode
        debugPrint('Falling back to audio mode...');
        _currentMode = PlaybackMode.audio;
        _videoPlayerController = null;

        // Play audio instead
        await playAudio(id: id);
        return;
      }

      if (!_isCurrentPlaybackRequest(generation)) return;
      _isLoading = false;
      unawaited(_recordCurrentSong(videoId));
      notifyListeners();
    } catch (e, stackTrace) {
      if (!_isCurrentPlaybackRequest(generation)) return;
      debugPrint('Error playing YouTube video: $e');
      debugPrint('Stack trace: $stackTrace');

      // Fallback to audio mode on any error
      _currentMode = PlaybackMode.audio;
      _videoPlayerController = null;
      _isLoading = false;
      notifyListeners();

      // Try to play audio as fallback
      try {
        if (!_isCurrentPlaybackRequest(generation)) return;
        await playAudio(id: id);
      } catch (audioError) {
        debugPrint('Audio fallback also failed: $audioError');
      }
    }
  }

  Future<void> _playLocalAudio(DownloadedAudio audio, int generation) async {
    if (!_isCurrentPlaybackRequest(generation)) return;
    _isPlayingOfflineAudio = audio == _currentOfflineAudio;
    _isPlayingDownloadedAudio = !_isPlayingOfflineAudio;
    _isPlayingDownloadedVideo = false;
    _videoInfo = null;
    _webVideoTitle = audio.title;
    _webVideoAuthor = audio.author;
    _webVideoThumbnailUrl = audio.thumbnailUrl;

    await _videoPlayerController?.dispose();
    if (!_isCurrentPlaybackRequest(generation)) return;
    _videoPlayerController = null;

    await _audioHandler.playFile(
      filePath: audio.filePath,
      id: audio.videoId.isEmpty ? audio.filePath : audio.videoId,
      title: audio.title,
      artist: audio.author,
      artUrl: audio.thumbnailUrl,
    );

    if (!_isCurrentPlaybackRequest(generation)) return;
    _isLoading = false;
    _ensureAutoplayQueueForCurrent(
      audio.videoId.isEmpty ? _currentVideoId ?? '' : audio.videoId,
    );
    unawaited(
      ref
          .read(playbackHistoryControllerProvider.notifier)
          .recordSong(
            videoId: audio.videoId.isEmpty ? audio.filePath : audio.videoId,
            title: audio.title,
            author: audio.author,
            thumbnailUrl: audio.thumbnailUrl,
          ),
    );
    notifyListeners();
  }

  void _attachVideoPlayerListeners(
    VideoPlayerController controller,
    int generation,
  ) {
    final completionGuard = VideoCompletionGuard();
    controller.addListener(() {
      if (!_isCurrentPlaybackRequest(generation) ||
          !identical(_videoPlayerController, controller)) {
        return;
      }

      final value = controller.value;
      if (value.hasError) {
        debugPrint('Video player error: ${value.errorDescription}');
      }
      if (!completionGuard.update(isCompleted: value.isCompleted)) return;

      final callback = onVideoComplete;
      if (callback != null) unawaited(callback());
    });
  }

  Future<void> replayCurrentVideo() async {
    final controller = _videoPlayerController;
    if (_currentMode != PlaybackMode.video ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    await controller.seekTo(Duration.zero);
    await controller.play();
  }

  void switchMode(PlaybackMode mode) {
    if (_currentMode != mode) {
      _currentMode = mode;
      notifyListeners();

      if (_currentVideoId != null) {
        autoPlay(id: _currentVideoId!);
      }
    }
  }

  Future<void> downloadCurrentAudio() async {
    final videoId = _currentVideoId;
    if (videoId == null || videoId.isEmpty) {
      ref
          .read(mainController)
          .sendMesage(
            LocaleKeys.download_no_song.tr(),
            textKey: const Key('toast-download-no-song'),
          );
      return;
    }

    await downloadAudio(id: videoId);
  }

  Future<void> downloadCurrentMedia() async {
    if (_currentMode == PlaybackMode.video) {
      await downloadCurrentVideo();
    } else {
      await downloadCurrentAudio();
    }
  }

  Future<void> downloadCurrentVideo() async {
    final videoId = _currentVideoId;
    if (videoId == null || videoId.isEmpty) {
      ref
          .read(mainController)
          .sendMesage(
            LocaleKeys.download_no_song.tr(),
            textKey: const Key('toast-download-no-video'),
          );
      return;
    }

    await downloadVideo(id: videoId);
  }

  Future<void> saveCurrentAudioForOffline() async {
    final videoId = _currentVideoId;
    if (videoId == null || videoId.isEmpty) {
      ref
          .read(mainController)
          .sendMesage(
            LocaleKeys.download_no_song.tr(),
            textKey: const Key('toast-offline-no-song'),
          );
      return;
    }

    await saveAudioForOffline(id: videoId);
  }

  Future<String?> saveAudioForOffline({required String id}) async {
    if (_isSavingOffline) return null;

    _AudioDownloadSource? source;

    try {
      final extracted = extractVideoId(id);
      final videoId = extracted ?? id;
      _currentVideoId = videoId;

      final existingOffline = await getOfflineAudio(videoId);
      if (existingOffline != null) {
        _offlineAudio = existingOffline;
        _offlineProgress = 1;
        notifyListeners();
        return existingOffline.filePath;
      }

      _isSavingOffline = true;
      _offlineProgress = 0;
      notifyListeners();

      source = await _openAudioDownload(videoId);
      final offlineAudio = await saveOfflineAudioStream(
        videoId: videoId,
        title: source.title,
        author: source.author,
        thumbnailUrl: source.thumbnailUrl,
        extension: source.extension,
        totalBytes: source.totalBytes,
        chunks: source.chunks,
        hasVideoTrack: source.hasVideoTrack,
        onProgress: (progress) {
          _offlineProgress = progress;
          notifyListeners();
        },
      );

      _offlineProgress = 1;
      _offlineAudio = offlineAudio;
      notifyListeners();

      ref
          .read(mainController)
          .sendMesage(
            LocaleKeys.offline_save_complete.tr(),
            textKey: const Key('toast-offline-save-complete'),
          );
      return offlineAudio.filePath;
    } catch (e, stackTrace) {
      debugPrint('Error saving audio offline: $e');
      debugPrint('Stack trace: $stackTrace');

      ref
          .read(mainController)
          .sendMesage(
            LocaleKeys.offline_save_error.tr(),
            textKey: const Key('toast-offline-save-error'),
          );
      return null;
    } finally {
      source?.dispose();
      _isSavingOffline = false;
      notifyListeners();
    }
  }

  Future<void> removeCurrentOfflineAudio() async {
    final offlineAudio = _currentOfflineAudio;
    if (offlineAudio == null) return;
    final deleted = await deleteOfflineAudio(offlineAudio);
    if (deleted) {
      _offlineAudio = null;
      _offlineProgress = 0;
      notifyListeners();
    }
    ref
        .read(mainController)
        .sendMesage(
          deleted
              ? LocaleKeys.offline_removed.tr()
              : LocaleKeys.download_delete_error.tr(),
          textKey: const Key('toast-offline-remove'),
        );
  }

  Future<String?> downloadAudio({required String id}) async {
    if (_isDownloading) return null;

    _AudioDownloadSource? source;

    try {
      final extracted = extractVideoId(id);
      final videoId = extracted ?? id;
      _currentVideoId = videoId;

      final existingDownload = await getDownloadedAudio(videoId);
      if (existingDownload != null) {
        _downloadedAudio = existingDownload;
        _downloadProgress = 1;
        notifyListeners();
        return existingDownload.filePath;
      }

      _isDownloading = true;
      _downloadProgress = 0;
      _downloadedAudio = null;
      notifyListeners();

      source = await _openAudioDownload(videoId);
      final downloadedAudio = await saveAudioStream(
        videoId: videoId,
        title: source.title,
        author: source.author,
        thumbnailUrl: source.thumbnailUrl,
        extension: source.extension,
        totalBytes: source.totalBytes,
        chunks: source.chunks,
        hasVideoTrack: source.hasVideoTrack,
        onProgress: (progress) {
          _downloadProgress = progress;
          notifyListeners();
        },
      );

      _downloadProgress = 1;
      _downloadedAudio = downloadedAudio;
      notifyListeners();

      ref
          .read(mainController)
          .sendMesage(
            LocaleKeys.download_complete.tr(),
            textKey: const Key('toast-download-complete'),
          );
      return downloadedAudio.filePath;
    } catch (e, stackTrace) {
      debugPrint('Error downloading audio: $e');
      debugPrint('Stack trace: $stackTrace');

      ref
          .read(mainController)
          .sendMesage(
            LocaleKeys.download_error.tr(),
            textKey: const Key('toast-download-error'),
          );
      return null;
    } finally {
      source?.dispose();
      _isDownloading = false;
      notifyListeners();
    }
  }

  Future<String?> downloadVideo({required String id}) async {
    if (_isDownloading) return null;

    YoutubeExplode? yt;

    try {
      final extracted = extractVideoId(id);
      final videoId = extracted ?? id;
      _currentVideoId = videoId;

      final existingDownload = await getDownloadedVideo(videoId);
      if (existingDownload != null) {
        _downloadedVideo = existingDownload;
        _downloadProgress = 1;
        notifyListeners();
        return existingDownload.filePath;
      }

      _isDownloading = true;
      _downloadProgress = 0;
      _downloadedVideo = null;
      notifyListeners();

      yt = YoutubeExplode();
      final video = await yt.videos.get(videoId);
      _videoInfo = video;

      final manifest = await yt.videos.streamsClient.getManifest(videoId);

      if (manifest.muxed.isEmpty) {
        throw StateError(LocaleKeys.no_video_streams.tr());
      }

      final preferredVideoStreams = manifest.muxed.where(
        (stream) => stream.container == StreamContainer.mp4,
      );
      final videoStream =
          (preferredVideoStreams.isEmpty
                  ? manifest.muxed
                  : preferredVideoStreams)
              .withHighestBitrate();

      final downloadedVideo = await saveVideoStream(
        videoId: videoId,
        title: video.title,
        author: video.author,
        thumbnailUrl: video.thumbnails.highResUrl,
        extension: videoStream.container.name,
        totalBytes: videoStream.size.totalBytes,
        chunks: yt.videos.streamsClient.get(videoStream),
        onProgress: (progress) {
          _downloadProgress = progress;
          notifyListeners();
        },
      );

      _downloadProgress = 1;
      _downloadedVideo = downloadedVideo;
      notifyListeners();

      ref
          .read(mainController)
          .sendMesage(
            LocaleKeys.download_complete.tr(),
            textKey: const Key('toast-download-video-complete'),
          );
      return downloadedVideo.filePath;
    } catch (e, stackTrace) {
      debugPrint('Error downloading video: $e');
      debugPrint('Stack trace: $stackTrace');

      ref
          .read(mainController)
          .sendMesage(
            LocaleKeys.download_error.tr(),
            textKey: const Key('toast-download-video-error'),
          );
      return null;
    } finally {
      yt?.close();
      _isDownloading = false;
      notifyListeners();
    }
  }

  void setSourceForId({required String id}) async {
    try {
      final extracted = extractVideoId(id);
      final videoId = extracted ?? id;
      if (kIsWeb) {
        _webEmbedVideoId = videoId;
        notifyListeners();
        return;
      }

      var yt = YoutubeExplode();
      var manifest = await yt.videos.streamsClient.getManifest(videoId);
      if (manifest.audioOnly.isEmpty) {
        debugPrint('No audio streams available for video: $videoId');
        yt.close();
        return;
      }
      var audioStream = manifest.audioOnly.withHighestBitrate();
      yt.close();

      await _audioPlayer.setSourceUrl(audioStream.url.toString());
    } catch (e) {
      debugPrint('Error setting source: $e');
    }
  }

  Future<void> _playYoutubeEmbed(String videoId, int generation) async {
    _webEmbedVideoId = videoId;
    try {
      final streamInfo = await _fetchPipedStreamInfo(videoId);
      if (!_isCurrentPlaybackRequest(generation)) return;
      _setWebVideoInfo(streamInfo);
    } catch (error) {
      if (!_isCurrentPlaybackRequest(generation)) return;
      debugPrint('Error loading web video metadata: $error');
      _videoInfo = null;
      _webVideoTitle = videoId;
      _webVideoAuthor = '';
      _webVideoThumbnailUrl = _youtubeThumbnailUrl(videoId);
    }

    await _audioPlayer.stop();
    if (!_isCurrentPlaybackRequest(generation)) return;
    await _videoPlayerController?.dispose();
    if (!_isCurrentPlaybackRequest(generation)) return;
    _videoPlayerController = null;

    _isLoading = false;
    unawaited(_recordCurrentSong(videoId));
    notifyListeners();
  }

  void _setWebVideoInfo(_PipedStreamInfo streamInfo) {
    _videoInfo = null;
    _webVideoTitle = streamInfo.title;
    _webVideoAuthor = streamInfo.uploader;
    _webVideoThumbnailUrl = streamInfo.thumbnailUrl;
  }

  Future<_PipedStreamInfo> _fetchPipedStreamInfo(String videoId) async {
    final uri = Uri.parse('$_pipedApiBaseUrl/streams/$videoId');
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Unexpected Piped status code: ${response.statusCode}',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid Piped stream response.');
    }

    final audioStream = _pickPipedAudioStream(decoded['audioStreams']);
    final videoStream = _pickPipedVideoStream(decoded['videoStreams']);

    return _PipedStreamInfo(
      title: decoded['title'] as String? ?? '',
      uploader: decoded['uploader'] as String? ?? '',
      thumbnailUrl: _youtubeThumbnailUrl(videoId),
      audioUrl: audioStream?.url,
      audioMimeType: audioStream?.mimeType,
      videoUrl: videoStream,
    );
  }

  Future<bool> _tryPlayPipedAudioFallback({
    required String videoId,
    required int generation,
    Duration? knownDuration,
    Duration? fallbackDuration,
  }) async {
    try {
      final streamInfo = await _fetchPipedStreamInfo(videoId);
      if (!_isCurrentPlaybackRequest(generation)) return false;
      final audioUrl = streamInfo.audioUrl;
      if (audioUrl == null || audioUrl.isEmpty) return false;

      final streamUri = Uri.tryParse(audioUrl);
      final canonicalDuration = streamUri == null
          ? knownDuration ?? fallbackDuration
          : _resolveAudioDuration(
              streamUri: streamUri,
              knownDuration: knownDuration,
              fallback: fallbackDuration,
            );

      await _audioHandler.playUrl(
        url: audioUrl,
        id: videoId,
        title: _videoInfo?.title ?? streamInfo.title,
        artist: _videoInfo?.author ?? streamInfo.uploader,
        artUrl: _videoInfo?.thumbnails.highResUrl ?? streamInfo.thumbnailUrl,
        mimeType: streamInfo.audioMimeType,
        canonicalDuration: canonicalDuration,
        requestHeaders: YoutubeHttpClient.defaultHeaders,
        proxyRemoteSource: _isApplePlatform,
      );
      return _isCurrentPlaybackRequest(generation);
    } catch (error, stackTrace) {
      if (!_isCurrentPlaybackRequest(generation)) return false;
      debugPrint('Piped audio fallback failed for $videoId: $error');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Abre los bytes del audio de [videoId] para guardarlo a disco.
  ///
  /// Prefiere youtube_explode (mejor metadata y bitrate) y cae a Piped cuando
  /// YouTube limita la IP por exceso de peticiones. Sin este respaldo, una
  /// descarga en primer plano fallaba solo porque el prefetch habia dejado la
  /// IP marcada, aunque la reproduccion siguiera funcionando (ella si cae a
  /// Piped desde siempre).
  Future<_AudioDownloadSource> _openAudioDownload(String videoId) async {
    if (!isYoutubeRateLimited) {
      try {
        return await _openAudioDownloadViaYoutube(videoId);
      } catch (error, stackTrace) {
        final rateLimited = reportYoutubeFailure(error);
        debugPrint('Download via youtube_explode failed for $videoId: $error');
        if (!rateLimited) debugPrintStack(stackTrace: stackTrace);
      }
    }
    return _openAudioDownloadViaPiped(videoId);
  }

  Future<_AudioDownloadSource> _openAudioDownloadViaYoutube(
    String videoId,
  ) async {
    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(videoId);
      _videoInfo = video;

      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final StreamInfo downloadStream;
      if (_isApplePlatform && manifest.muxed.isNotEmpty) {
        downloadStream = pickYoutubePlaybackStream(
          manifest,
          preferMuxed: true,
        )!;
      } else {
        if (manifest.audioOnly.isEmpty) {
          throw StateError(LocaleKeys.no_audio_streams.tr());
        }

        final preferredAudioStreams = manifest.audioOnly.where(
          (stream) =>
              stream.container == StreamContainer.mp4 ||
              stream.codec.subtype == 'mp4a.40.2',
        );
        final pool = preferredAudioStreams.isEmpty
            ? manifest.audioOnly.toList()
            : preferredAudioStreams.toList();
        final quality = ref.read(audioDownloadQualityControllerProvider);
        downloadStream = _pickAudioForQuality(pool, quality);
      }
      final hasVideoTrack = downloadStream is MuxedStreamInfo;

      debugPrint(
        'Downloading YouTube ${hasVideoTrack ? 'muxed MP4' : 'audio-only'} '
        'stream for $videoId (${downloadStream.size.totalBytes} bytes).',
      );

      return _AudioDownloadSource(
        title: video.title,
        author: video.author,
        thumbnailUrl: video.thumbnails.highResUrl,
        extension: downloadStream.container.name,
        totalBytes: downloadStream.size.totalBytes,
        chunks: yt.videos.streamsClient.get(downloadStream),
        hasVideoTrack: hasVideoTrack,
        dispose: yt.close,
      );
    } catch (_) {
      yt.close();
      rethrow;
    }
  }

  /// Los bytes salen de googlevideo.com por la URL que da Piped, sin pasar por
  /// youtube.com: es lo que permite descargar aun con la IP marcada.
  Future<_AudioDownloadSource> _openAudioDownloadViaPiped(
    String videoId,
  ) async {
    final uri = Uri.parse('$_pipedApiBaseUrl/streams/$videoId');
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Unexpected Piped status code: ${response.statusCode}',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid Piped stream response.');
    }

    final quality = ref.read(audioDownloadQualityControllerProvider);
    final stream = _pickPipedDownloadStream(decoded['audioStreams'], quality);
    if (stream == null) {
      throw StateError(LocaleKeys.no_audio_streams.tr());
    }

    final streamUri = Uri.parse(stream.url);
    final client = http.Client();
    try {
      final audioResponse = await client.send(http.Request('GET', streamUri));
      if (audioResponse.statusCode < 200 || audioResponse.statusCode >= 300) {
        throw http.ClientException(
          'Unexpected audio status code: ${audioResponse.statusCode}',
          streamUri,
        );
      }

      return _AudioDownloadSource(
        title: decoded['title'] as String? ?? videoId,
        author: decoded['uploader'] as String? ?? '',
        thumbnailUrl: _youtubeThumbnailUrl(videoId),
        extension: _downloadExtensionFor(stream.mimeType),
        totalBytes: stream.contentLength > 0
            ? stream.contentLength
            : (audioResponse.contentLength ?? 0),
        chunks: audioResponse.stream,
        dispose: client.close,
      );
    } catch (_) {
      client.close();
      rethrow;
    }
  }

  /// A diferencia del stream para reproducir, aqui se prefiere M4A: es lo que
  /// abre cualquier reproductor del sistema (opus no suena en iOS).
  _PipedDownloadStream? _pickPipedDownloadStream(
    Object? streams,
    AudioDownloadQuality quality,
  ) {
    if (streams is! List || streams.isEmpty) return null;

    final typedStreams = streams
        .whereType<Map>()
        .map((stream) => Map<String, dynamic>.from(stream))
        .where((stream) => (stream['url'] as String? ?? '').isNotEmpty)
        .toList();
    if (typedStreams.isEmpty) return null;

    bool isM4a(Map<String, dynamic> stream) {
      final format = (stream['format'] as String? ?? '').toUpperCase();
      final mimeType = (stream['mimeType'] as String? ?? '').toLowerCase();
      return format.contains('M4A') || mimeType.contains('mp4');
    }

    final m4a = typedStreams.where(isM4a).toList();
    final pool = m4a.isEmpty ? typedStreams : m4a;
    pool.sort((a, b) {
      final aBitrate = a['bitrate'] as int? ?? 0;
      final bBitrate = b['bitrate'] as int? ?? 0;
      return aBitrate.compareTo(bBitrate);
    });

    final picked = switch (quality) {
      AudioDownloadQuality.low => pool.first,
      AudioDownloadQuality.high => pool.last,
      AudioDownloadQuality.medium => pool[pool.length ~/ 2],
    };

    return _PipedDownloadStream(
      url: picked['url'] as String,
      mimeType: picked['mimeType'] as String? ?? 'audio/mp4',
      contentLength: picked['contentLength'] as int? ?? 0,
    );
  }

  _PipedAudioStream? _pickPipedAudioStream(Object? streams) {
    if (streams is! List || streams.isEmpty) return null;
    final typedStreams = streams
        .whereType<Map>()
        .map((stream) => Map<String, dynamic>.from(stream))
        .where((stream) => (stream['url'] as String? ?? '').isNotEmpty)
        .toList();
    if (typedStreams.isEmpty) return null;

    typedStreams.sort((a, b) {
      if (_isApplePlatform) {
        final aIsM4a = _isPipedM4a(a) ? 1 : 0;
        final bIsM4a = _isPipedM4a(b) ? 1 : 0;
        if (aIsM4a != bIsM4a) return bIsM4a.compareTo(aIsM4a);
      }
      final aIsOpus = a['format'] == 'WEBMA_OPUS' ? 1 : 0;
      final bIsOpus = b['format'] == 'WEBMA_OPUS' ? 1 : 0;
      if (aIsOpus != bIsOpus) return bIsOpus.compareTo(aIsOpus);
      final aBitrate = a['bitrate'] as int? ?? 0;
      final bBitrate = b['bitrate'] as int? ?? 0;
      return bBitrate.compareTo(aBitrate);
    });

    final stream = typedStreams.first;
    return _PipedAudioStream(
      url: stream['url'] as String,
      mimeType: stream['mimeType'] as String? ?? 'audio/webm',
    );
  }

  bool _isPipedM4a(Map<String, dynamic> stream) {
    final format = (stream['format'] as String? ?? '').toUpperCase();
    final mimeType = (stream['mimeType'] as String? ?? '').toLowerCase();
    return format.contains('M4A') || mimeType.contains('mp4');
  }

  String _youtubeThumbnailUrl(String videoId) {
    return 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
  }

  String? _pickPipedVideoStream(Object? streams) {
    if (streams is! List || streams.isEmpty) return null;
    final typedStreams = streams
        .whereType<Map>()
        .map((stream) => Map<String, dynamic>.from(stream))
        .where((stream) {
          final url = stream['url'] as String? ?? '';
          final videoOnly = stream['videoOnly'] as bool? ?? false;
          return url.isNotEmpty && !videoOnly;
        })
        .toList();
    if (typedStreams.isEmpty) return null;

    typedStreams.sort((a, b) {
      final aHeight = a['height'] as int? ?? 0;
      final bHeight = b['height'] as int? ?? 0;
      if (aHeight != bHeight) return bHeight.compareTo(aHeight);
      final aBitrate = a['bitrate'] as int? ?? 0;
      final bBitrate = b['bitrate'] as int? ?? 0;
      return bBitrate.compareTo(aBitrate);
    });

    return typedStreams.first['url'] as String;
  }

  Future<void> playDownloadedAudio(DownloadedAudio downloadedAudio) async {
    final generation = _beginPlaybackRequest();
    try {
      _isLoading = true;
      _currentMode = PlaybackMode.audio;
      _isPlayingDownloadedAudio = true;
      _isPlayingDownloadedVideo = false;
      _currentVideoId = downloadedAudio.videoId.isEmpty
          ? _currentVideoId
          : downloadedAudio.videoId;
      _downloadedAudio = downloadedAudio;
      notifyListeners();

      await _audioHandler.stop();
      if (!_isCurrentPlaybackRequest(generation)) return;
      await _videoPlayerController?.pause();
      if (!_isCurrentPlaybackRequest(generation)) return;
      await _videoPlayerController?.dispose();
      if (!_isCurrentPlaybackRequest(generation)) return;
      _videoPlayerController = null;
      _webEmbedVideoId = null;
      await _audioHandler.playFile(
        filePath: downloadedAudio.filePath,
        id: downloadedAudio.videoId.isEmpty
            ? downloadedAudio.filePath
            : downloadedAudio.videoId,
        title: downloadedAudio.title,
        artist: downloadedAudio.author,
        artUrl: downloadedAudio.thumbnailUrl,
      );

      if (!_isCurrentPlaybackRequest(generation)) return;
      _isLoading = false;
      unawaited(
        ref
            .read(playbackHistoryControllerProvider.notifier)
            .recordSong(
              videoId: downloadedAudio.videoId.isEmpty
                  ? downloadedAudio.filePath
                  : downloadedAudio.videoId,
              title: downloadedAudio.title,
              author: downloadedAudio.author,
              thumbnailUrl: downloadedAudio.thumbnailUrl,
            ),
      );
      notifyListeners();
    } catch (e, stackTrace) {
      if (!_isCurrentPlaybackRequest(generation)) return;
      debugPrint('Error playing downloaded audio: $e');
      debugPrint('Stack trace: $stackTrace');
      _isLoading = false;
      notifyListeners();
      ref
          .read(mainController)
          .sendMesage(
            LocaleKeys.download_error.tr(),
            textKey: const Key('toast-download-file-error'),
          );
    }
  }

  Future<void> playDownloadedVideo(DownloadedAudio downloadedVideo) async {
    final generation = _beginPlaybackRequest();
    VideoPlayerController? nextVideoController;
    try {
      _isLoading = true;
      _currentMode = PlaybackMode.video;
      _isPlayingDownloadedAudio = false;
      _isPlayingDownloadedVideo = true;
      _currentVideoId = downloadedVideo.videoId.isEmpty
          ? _currentVideoId
          : downloadedVideo.videoId;
      _downloadedVideo = downloadedVideo;
      notifyListeners();

      await _audioHandler.stop();
      if (!_isCurrentPlaybackRequest(generation)) return;
      await _videoPlayerController?.dispose();
      if (!_isCurrentPlaybackRequest(generation)) return;
      _webEmbedVideoId = null;
      nextVideoController = createLocalVideoController(
        downloadedVideo.filePath,
      );
      await nextVideoController.initialize();
      if (!_isCurrentPlaybackRequest(generation)) {
        await nextVideoController.dispose();
        return;
      }
      _videoPlayerController = nextVideoController;
      _attachVideoPlayerListeners(nextVideoController, generation);
      await nextVideoController.play();

      if (!_isCurrentPlaybackRequest(generation)) {
        if (identical(_videoPlayerController, nextVideoController)) {
          _videoPlayerController = null;
        }
        await nextVideoController.dispose();
        return;
      }
      _isLoading = false;
      unawaited(
        ref
            .read(playbackHistoryControllerProvider.notifier)
            .recordSong(
              videoId: downloadedVideo.videoId.isEmpty
                  ? downloadedVideo.filePath
                  : downloadedVideo.videoId,
              title: downloadedVideo.title,
              author: downloadedVideo.author,
              thumbnailUrl: downloadedVideo.thumbnailUrl,
            ),
      );
      notifyListeners();
    } catch (e, stackTrace) {
      if (identical(_videoPlayerController, nextVideoController)) {
        _videoPlayerController = null;
      }
      try {
        await nextVideoController?.dispose();
      } catch (_) {}
      if (!_isCurrentPlaybackRequest(generation)) return;
      debugPrint('Error playing downloaded video: $e');
      debugPrint('Stack trace: $stackTrace');
      _isLoading = false;
      notifyListeners();
      ref
          .read(mainController)
          .sendMesage(
            LocaleKeys.download_error.tr(),
            textKey: const Key('toast-download-video-file-error'),
          );
    }
  }

  void playForId({required String id}) async {
    await autoPlay(id: id);
  }

  String? extractVideoId(String url) {
    final regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  void playListSong({String? playListId}) {
    if (playListId != null) {
      debugPrint('Playlist ID: $playListId');
    }
  }

  Future<void> _recordCurrentSong(String videoId) {
    _ensureAutoplayQueueForCurrent(videoId);
    return ref
        .read(playbackHistoryControllerProvider.notifier)
        .recordSong(
          videoId: videoId,
          title: displayTitle ?? videoId,
          author: displayAuthor ?? '',
          thumbnailUrl: displayThumbnailUrl ?? '',
        );
  }

  /// Songs opened from favorites, a direct route or a saved playlist do not
  /// arrive with a search-results queue. Seed autoplay from the resolved
  /// metadata so those entry points also get a next song and background
  /// refills. Existing search/home queues are preserved.
  void _ensureAutoplayQueueForCurrent(String videoId) {
    if (videoId.isEmpty || !ref.read(autoplayEnabledControllerProvider)) {
      return;
    }

    final title = displayTitle?.trim() ?? '';
    if (title.isEmpty) return;

    final notifier = ref.read(autoplayQueueControllerProvider.notifier);
    final queue = ref.read(autoplayQueueControllerProvider);
    if (queue.current?.videoId == videoId) {
      unawaited(notifier.ensureNext());
      return;
    }

    notifier.enqueue([
      YouTubeSearchSuggestion(
        videoId: videoId,
        displayText: title,
        channelTitle: displayAuthor?.trim() ?? '',
        thumbnailUrl: displayThumbnailUrl?.trim() ?? '',
        duration: _videoInfo?.duration,
      ),
    ], 0);
  }

  @override
  void dispose() {
    onVideoComplete = null;
    _videoPlayerController?.dispose();
    super.dispose();
  }
}
