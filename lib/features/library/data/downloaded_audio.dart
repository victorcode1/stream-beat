enum DownloadedMediaType {
  audio,
  video;

  static DownloadedMediaType fromName(String? name) {
    return DownloadedMediaType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => DownloadedMediaType.audio,
    );
  }
}

class DownloadedAudio {
  const DownloadedAudio({
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.filePath,
    required this.downloadedAt,
    this.mediaType = DownloadedMediaType.audio,
    this.hasVideoTrack = false,
  });

  factory DownloadedAudio.fromJson(Map<String, dynamic> json) {
    return DownloadedAudio(
      videoId: json['videoId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      filePath: json['filePath'] as String? ?? '',
      downloadedAt:
          DateTime.tryParse(json['downloadedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      mediaType: DownloadedMediaType.fromName(json['mediaType'] as String?),
      hasVideoTrack: json['hasVideoTrack'] as bool? ?? false,
    );
  }

  final String videoId;
  final String title;
  final String author;
  final String thumbnailUrl;
  final String filePath;
  final DateTime downloadedAt;
  final DownloadedMediaType mediaType;
  final bool hasVideoTrack;

  bool get isVideo => mediaType == DownloadedMediaType.video;

  DownloadedAudio copyWith({
    String? title,
    String? author,
    String? thumbnailUrl,
    String? filePath,
  }) => DownloadedAudio(
    videoId: videoId,
    title: title ?? this.title,
    author: author ?? this.author,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    filePath: filePath ?? this.filePath,
    downloadedAt: downloadedAt,
    mediaType: mediaType,
    hasVideoTrack: hasVideoTrack,
  );

  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'title': title,
      'author': author,
      'thumbnailUrl': thumbnailUrl,
      'filePath': filePath,
      'downloadedAt': downloadedAt.toIso8601String(),
      'mediaType': mediaType.name,
      'hasVideoTrack': hasVideoTrack,
    };
  }
}
