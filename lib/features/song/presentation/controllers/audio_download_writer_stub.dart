import 'package:flow_music/features/library/data/downloaded_audio.dart';

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
}) {
  throw UnsupportedError('Audio downloads are not supported on this platform.');
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
}) {
  throw UnsupportedError('Video downloads are not supported on this platform.');
}

Future<DownloadedAudio?> getDownloadedAudio(String videoId) async {
  return null;
}

Future<DownloadedAudio?> getDownloadedVideo(String videoId) async {
  return null;
}

Future<List<DownloadedAudio>> listDownloadedAudios() async {
  return const [];
}

Future<bool> deleteDownloadedAudio(DownloadedAudio audio) async {
  return false;
}

class DownloadedFileInfo {
  const DownloadedFileInfo({required this.exists, required this.sizeBytes});

  final bool exists;
  final int sizeBytes;
}

Future<DownloadedFileInfo> getDownloadedFileInfo(DownloadedAudio audio) async {
  return const DownloadedFileInfo(exists: false, sizeBytes: 0);
}

class ShareableDownload {
  const ShareableDownload({required this.path, this.mimeType});

  final String path;
  final String? mimeType;
}

Future<ShareableDownload> prepareDownloadedForSharing(
  DownloadedAudio audio,
) async {
  return ShareableDownload(path: audio.filePath);
}

Future<DownloadedAudio> repairDownloadedMetadata(DownloadedAudio audio) async =>
    audio;
