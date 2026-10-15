class RadioStation {
  const RadioStation({
    required this.stationUuid,
    required this.name,
    required this.url,
    required this.urlResolved,
    required this.homepage,
    required this.favicon,
    required this.tags,
    required this.country,
    required this.countryCode,
    required this.language,
    required this.codec,
    required this.bitrate,
    required this.votes,
    required this.clickCount,
    required this.lastCheckOk,
    this.lastCheckTime,
    this.lastCheckOkTime,
    this.hls = 0,
    this.sslError = 0,
    required this.latitude,
    required this.longitude,
    required this.rawData,
  });

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    return RadioStation(
      stationUuid: json['stationuuid'] as String? ?? '',
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      urlResolved: json['url_resolved'] as String? ?? '',
      homepage: json['homepage'] as String? ?? '',
      favicon: json['favicon'] as String? ?? '',
      tags: json['tags'] as String? ?? '',
      country: json['country'] as String? ?? '',
      countryCode: json['countrycode'] as String? ?? '',
      language: json['language'] as String? ?? '',
      codec: json['codec'] as String? ?? '',
      bitrate: _parseInt(json['bitrate']),
      votes: _parseInt(json['votes']),
      clickCount: _parseInt(json['clickcount']),
      lastCheckOk: _parseInt(json['lastcheckok']),
      lastCheckTime: _parseDateTime(
        json['lastchecktime_iso8601'] ?? json['lastchecktime'],
      ),
      lastCheckOkTime: _parseDateTime(
        json['lastcheckoktime_iso8601'] ?? json['lastcheckoktime'],
      ),
      hls: _parseInt(json['hls']),
      sslError: _parseInt(json['ssl_error']),
      latitude: _parseCoordinate(json['geo_lat']),
      longitude: _parseCoordinate(json['geo_long']),
      rawData: Map.unmodifiable(json),
    );
  }

  final String stationUuid;
  final String name;
  final String url;
  final String urlResolved;
  final String homepage;
  final String favicon;
  final String tags;
  final String country;
  final String countryCode;
  final String language;
  final String codec;
  final int bitrate;
  final int votes;
  final int clickCount;
  final int lastCheckOk;
  final DateTime? lastCheckTime;
  final DateTime? lastCheckOkTime;
  final int hls;
  final int sslError;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic> rawData;

  String get artworkUrl {
    final normalizedUrl = favicon.trim();
    if (normalizedUrl.isEmpty) return '';

    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null || uri.host.isEmpty) return '';

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return '';

    return uri.toString();
  }

  String get streamUrl =>
      urlResolved.trim().isNotEmpty ? urlResolved.trim() : url.trim();
  Uri? get streamUri {
    final uri = Uri.tryParse(streamUrl);
    if (uri == null || uri.host.isEmpty) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;
    return uri;
  }

  bool get isCustomStation => stationUuid.startsWith('custom-');

  bool get isPlayable => streamUri != null;
  bool get isHttps => streamUri?.scheme.toLowerCase() == 'https';
  bool get isHttp => streamUri?.scheme.toLowerCase() == 'http';
  bool get isHls => hls == 1;
  bool get hasSslError => sslError == 1;
  bool get hasGeoPoint => latitude != null && longitude != null;

  static bool isPlayableUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.host.isEmpty) return false;
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(rawData);
}

double? _parseCoordinate(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

int _parseInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value.trim())?.toUtc();
}
