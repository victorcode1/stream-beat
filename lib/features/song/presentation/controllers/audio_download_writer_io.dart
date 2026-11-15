import 'dart:convert';
import 'dart:io';

import 'package:flow_music/features/library/data/downloaded_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flow_music/features/library/data/download_metadata_recovery.dart';

Future<DownloadedAudio> saveAudioStream({
  required String videoId,
  required String title,
  required String author,
  required String thumbnailUrl,
  required String extension,
  required int totalBytes,
  required Stream<List<int>> chunks,
  required void Function(double progress) onProgress,
  bool hasVideoTrack = false,
}) async {
  return _saveMediaStream(
    videoId: videoId,
    title: title,
    author: author,
    thumbnailUrl: thumbnailUrl,
    extension: extension,
    totalBytes: totalBytes,
    chunks: chunks,
    onProgress: onProgress,
    mediaType: DownloadedMediaType.audio,
    hasVideoTrack: hasVideoTrack,
  );
}

Future<DownloadedAudio> saveVideoStream({
  required String videoId,
  required String title,
  required String author,
  required String thumbnailUrl,
  required String extension,
  required int totalBytes,
  required Stream<List<int>> chunks,
  required void Function(double progress) onProgress,
}) async {
  return _saveMediaStream(
    videoId: videoId,
    title: title,
    author: author,
    thumbnailUrl: thumbnailUrl,
    extension: extension,
    totalBytes: totalBytes,
    chunks: chunks,
    onProgress: onProgress,
    mediaType: DownloadedMediaType.video,
    hasVideoTrack: true,
  );
}

Future<DownloadedAudio> _saveMediaStream({
  required String videoId,
  required String title,
  required String author,
  required String thumbnailUrl,
  required String extension,
  required int totalBytes,
  required Stream<List<int>> chunks,
  required void Function(double progress) onProgress,
  required DownloadedMediaType mediaType,
  required bool hasVideoTrack,
}) async {
  IOSink? output;
  File? outputFile;

  try {
    final downloadsDirectory = await _downloadsDirectory();
    final existing = mediaType == DownloadedMediaType.video
        ? await getDownloadedVideo(videoId)
        : await getDownloadedAudio(videoId);
    if (existing != null) {
      return existing;
    }

    final resolvedExtension =
        mediaType == DownloadedMediaType.audio &&
            extension.toLowerCase() == 'mp4' &&
            !hasVideoTrack
        ? 'm4a'
        : extension;
    outputFile = File(
      '${downloadsDirectory.path}${Platform.pathSeparator}${_safeFileName(_fileBaseName(videoId, mediaType), resolvedExtension)}',
    );
    output = outputFile.openWrite(mode: FileMode.writeOnly);

    var downloadedBytes = 0;
    var lastProgressUpdate = DateTime.now();

    await for (final chunk in chunks) {
      downloadedBytes += chunk.length;
      output.add(chunk);

      if (totalBytes > 0) {
        final now = DateTime.now();
        if (now.difference(lastProgressUpdate).inMilliseconds >= 120 ||
            downloadedBytes == totalBytes) {
          onProgress((downloadedBytes / totalBytes).clamp(0, 1).toDouble());
          lastProgressUpdate = now;
        }
      }
    }

    await output.flush();
    await output.close();
    output = null;

    if (downloadedBytes == 0 ||
        (totalBytes > 0 && downloadedBytes < totalBytes)) {
      throw StateError(
        'Incomplete media download: received $downloadedBytes of '
        '$totalBytes bytes.',
      );
    }

    final downloadedAudio = DownloadedAudio(
      videoId: videoId,
      title: title,
      author: author,
      thumbnailUrl: thumbnailUrl,
      filePath: outputFile.path,
      downloadedAt: DateTime.now(),
      mediaType: mediaType,
      hasVideoTrack: hasVideoTrack,
    );
    await _writeMetadata(downloadsDirectory, downloadedAudio);

    return downloadedAudio;
  } catch (_) {
    try {
      await output?.close();
    } catch (_) {
      // Ignore close errors while cleaning up a failed download.
    }

    try {
      if (outputFile != null && await outputFile.exists()) {
        await outputFile.delete();
      }
    } catch (_) {
      // Ignore cleanup errors for partial files.
    }

    rethrow;
  }
}

Future<DownloadedAudio?> getDownloadedAudio(String videoId) async {
  return _getDownloadedMedia(videoId, DownloadedMediaType.audio);
}

Future<DownloadedAudio?> getDownloadedVideo(String videoId) async {
  return _getDownloadedMedia(videoId, DownloadedMediaType.video);
}

Future<DownloadedAudio?> _getDownloadedMedia(
  String videoId,
  DownloadedMediaType mediaType,
) async {
  final downloadsDirectory = await _downloadsDirectory();
  final metadata = await _readMetadata(downloadsDirectory, videoId, mediaType);
  if (metadata != null) {
    final file = File(metadata.filePath);
    if (await file.exists() && await file.length() > 0) {
      return metadata;
    }
  }

  final safeVideoId = _safeBaseName(_fileBaseName(videoId, mediaType));
  await for (final entity in downloadsDirectory.list()) {
    if (entity is! File || entity.path.endsWith('.json')) continue;
    if (await entity.length() == 0) continue;

    final fileName = _fileName(entity.path);
    final dotIndex = fileName.lastIndexOf('.');
    final baseName = dotIndex == -1
        ? fileName
        : fileName.substring(0, dotIndex);
    if (baseName == safeVideoId) {
      return DownloadedAudio(
        videoId: videoId,
        title: videoId,
        author: '',
        thumbnailUrl: '',
        filePath: entity.path,
        downloadedAt: await entity.lastModified(),
        mediaType: mediaType,
      );
    }
  }

  return null;
}

Future<List<DownloadedAudio>> listDownloadedAudios() async {
  final downloadsDirectory = await _downloadsDirectory();
  final downloads = <DownloadedAudio>[];
  final metadataByPath = <String>{};

  await for (final entity in downloadsDirectory.list()) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    final metadata = await _readMetadataFile(entity);
    if (metadata != null) {
      final file = File(metadata.filePath);
      if (await file.exists() && await file.length() > 0) {
        downloads.add(metadata);
        metadataByPath.add(metadata.filePath);
      }
    }
  }

  await for (final entity in downloadsDirectory.list()) {
    if (entity is! File ||
        entity.path.endsWith('.json') ||
        metadataByPath.contains(entity.path)) {
      continue;
    }
    if (await entity.length() == 0) continue;

    downloads.add(
      DownloadedAudio(
        videoId: _videoIdFromFilePath(entity.path),
        title: _titleFromFilePath(entity.path),
        author: '',
        thumbnailUrl: '',
        filePath: entity.path,
        downloadedAt: await entity.lastModified(),
        mediaType: DownloadedMediaType.audio,
      ),
    );
  }

  for (var i = 0; i < downloads.length; i++) {
    final repaired = recoverLocalDownloadMetadata(downloads[i]);
    final changed = !identical(repaired, downloads[i]);
    downloads[i] = repaired;
    if (changed && repaired.videoId.isNotEmpty) {
      await _writeMetadata(downloadsDirectory, repaired);
    }
  }
  downloads.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
  return downloads;
}

class DownloadedFileInfo {
  const DownloadedFileInfo({required this.exists, required this.sizeBytes});

  final bool exists;
  final int sizeBytes;
}

Future<DownloadedFileInfo> getDownloadedFileInfo(DownloadedAudio audio) async {
  if (audio.filePath.isEmpty) {
    return const DownloadedFileInfo(exists: false, sizeBytes: 0);
  }
  try {
    final file = File(audio.filePath);
    if (!await file.exists()) {
      return const DownloadedFileInfo(exists: false, sizeBytes: 0);
    }
    return DownloadedFileInfo(exists: true, sizeBytes: await file.length());
  } catch (_) {
    return const DownloadedFileInfo(exists: false, sizeBytes: 0);
  }
}

class ShareableDownload {
  const ShareableDownload({required this.path, this.mimeType});

  final String path;
  final String? mimeType;
}

Future<ShareableDownload> prepareDownloadedForSharing(
  DownloadedAudio audio,
) async {
  final originalPath = audio.filePath;
  if (originalPath.isEmpty) {
    return ShareableDownload(path: originalPath);
  }
  final ext = _extensionOf(originalPath);

  if (audio.isVideo || audio.hasVideoTrack) {
    return ShareableDownload(path: originalPath, mimeType: _videoMime(ext));
  }

  // Compatibilidad con descargas audio-only antiguas que conservaron `.mp4`.
  // Las descargas muxed ya salieron arriba con MIME de video y no deben
  // renombrarse a `.m4a`, porque contienen una pista de video real.
  if (ext == 'mp4') {
    try {
      final tempDir = await getTemporaryDirectory();
      final base = _safeBaseName(
        audio.title.isEmpty ? audio.videoId : audio.title,
      );
      final tempPath =
          '${tempDir.path}${Platform.pathSeparator}'
          '${base.isEmpty ? 'song' : base}.m4a';
      await File(originalPath).copy(tempPath);
      return ShareableDownload(path: tempPath, mimeType: 'audio/mp4');
    } catch (_) {
      return ShareableDownload(path: originalPath, mimeType: 'audio/mp4');
    }
  }

  return ShareableDownload(path: originalPath, mimeType: _audioMime(ext));
}

String _extensionOf(String path) {
  final fileName = _fileName(path);
  final dot = fileName.lastIndexOf('.');
  if (dot == -1 || dot == fileName.length - 1) return '';
  return fileName.substring(dot + 1).toLowerCase();
}

String _audioMime(String ext) {
  return switch (ext) {
    'mp4' || 'm4a' || 'aac' => 'audio/mp4',
    'webm' => 'audio/webm',
    'mp3' => 'audio/mpeg',
    'ogg' || 'opus' => 'audio/ogg',
    'wav' => 'audio/wav',
    _ => 'audio/*',
  };
}

String _videoMime(String ext) {
  return switch (ext) {
    'mp4' || 'm4v' => 'video/mp4',
    'webm' => 'video/webm',
    'mov' => 'video/quicktime',
    _ => 'video/*',
  };
}

Future<bool> deleteDownloadedAudio(DownloadedAudio audio) async {
  var deletedSomething = false;
  try {
    if (audio.filePath.isNotEmpty) {
      final file = File(audio.filePath);
      if (await file.exists()) {
        await file.delete();
        deletedSomething = true;
      }
    }
  } catch (_) {
    // Ignore file deletion errors and continue cleaning up metadata.
  }

  try {
    final downloadsDirectory = await _downloadsDirectory();
    final metadata = _typedMetadataFile(
      downloadsDirectory,
      audio.videoId,
      audio.mediaType,
    );
    if (await metadata.exists()) {
      await metadata.delete();
      deletedSomething = true;
    }
    if (audio.mediaType == DownloadedMediaType.audio) {
      final legacy = _metadataFile(downloadsDirectory, audio.videoId);
      if (legacy.path != metadata.path && await legacy.exists()) {
        await legacy.delete();
        deletedSomething = true;
      }
    }
  } catch (_) {
    // Ignore metadata cleanup errors.
  }

  return deletedSomething;
}

Future<Directory> _downloadsDirectory() async {
  final documentsDirectory = await getApplicationDocumentsDirectory();
  final downloadsDirectory = Directory(
    '${documentsDirectory.path}${Platform.pathSeparator}downloads',
  );

  if (!await downloadsDirectory.exists()) {
    await downloadsDirectory.create(recursive: true);
  }

  return downloadsDirectory;
}

String _safeFileName(String title, String extension) {
  final sanitizedTitle = _safeBaseName(title);
  final fallbackTitle = sanitizedTitle.isEmpty ? 'song' : sanitizedTitle;

  return '$fallbackTitle.$extension';
}

String _safeBaseName(String value) {
  return value
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

File _metadataFile(Directory directory, String videoId) {
  return File(
    '${directory.path}${Platform.pathSeparator}${_safeBaseName(_fileBaseName(videoId, DownloadedMediaType.audio))}.json',
  );
}

File _typedMetadataFile(
  Directory directory,
  String videoId,
  DownloadedMediaType mediaType,
) {
  return File(
    '${directory.path}${Platform.pathSeparator}${_safeBaseName(_fileBaseName(videoId, mediaType))}.json',
  );
}

Future<void> _writeMetadata(
  Directory directory,
  DownloadedAudio downloadedAudio,
) async {
  final file = _typedMetadataFile(
    directory,
    downloadedAudio.videoId,
    downloadedAudio.mediaType,
  );
  await file.writeAsString(jsonEncode(downloadedAudio.toJson()));
}

Future<DownloadedAudio?> _readMetadata(
  Directory directory,
  String videoId,
  DownloadedMediaType mediaType,
) async {
  final typed = await _readMetadataFile(
    _typedMetadataFile(directory, videoId, mediaType),
  );
  if (typed != null) return typed;
  if (mediaType == DownloadedMediaType.audio) {
    return _readMetadataFile(_metadataFile(directory, videoId));
  }
  return null;
}

Future<DownloadedAudio?> _readMetadataFile(File file) async {
  try {
    if (!await file.exists()) return null;
    final json = jsonDecode(await file.readAsString());
    if (json is! Map<String, dynamic>) return null;
    final stored = DownloadedAudio.fromJson(json);
    final localFile = File(
      '${file.parent.path}${Platform.pathSeparator}${_fileName(stored.filePath)}',
    );
    final currentPath = await localFile.exists()
        ? localFile.path
        : stored.filePath;
    return stored.copyWith(filePath: currentPath);
  } catch (_) {
    return null;
  }
}

String _fileName(String path) {
  return path.split(Platform.pathSeparator).last;
}

String _titleFromFilePath(String path) {
  final fileName = _fileName(path);
  final dotIndex = fileName.lastIndexOf('.');
  return dotIndex == -1 ? fileName : fileName.substring(0, dotIndex);
}

String _fileBaseName(String videoId, DownloadedMediaType mediaType) {
  return mediaType == DownloadedMediaType.video ? '$videoId-video' : videoId;
}

String _videoIdFromFilePath(String path) {
  final name = _titleFromFilePath(path).replaceFirst(RegExp(r'-video$'), '');
  return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(name) ? name : '';
}

Future<DownloadedAudio> repairDownloadedMetadata(DownloadedAudio audio) async {
  final repaired = await recoverDownloadMetadata(audio);
  if (!identical(audio, repaired) && repaired.videoId.isNotEmpty) {
    await _writeMetadata(await _downloadsDirectory(), repaired);
  }
  return repaired;
}
