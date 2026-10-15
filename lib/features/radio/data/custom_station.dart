import 'dart:math';

import 'package:flow_music/features/radio/data/models/radio_station.dart';

Uri? stationWebUri(String value) {
  final normalized = value.trim();
  // Uri normalizes an empty userinfo (https://@host) away, so check the
  // original authority before parsing as well.
  if (RegExp(r'\s').hasMatch(normalized) ||
      RegExp(
        r'^https?://[^/?#]*@',
        caseSensitive: false,
      ).hasMatch(normalized)) {
    return null;
  }
  final uri = Uri.tryParse(normalized);
  if (uri == null ||
      uri.host.isEmpty ||
      uri.authority.contains('@') ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  return uri;
}

RadioStation createCustomStation({
  required String name,
  required String streamUrl,
  String homepage = '',
}) {
  if (name.trim().isEmpty) throw const FormatException('name');
  final stream = stationWebUri(streamUrl);
  final website = homepage.trim().isEmpty ? null : stationWebUri(homepage);
  if (stream == null || (homepage.trim().isNotEmpty && website == null)) {
    throw const FormatException('url');
  }
  final random = Random.secure();
  final id = List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  return RadioStation.fromJson({
    'stationuuid': 'custom-$id',
    'name': name.trim(),
    'url': stream.toString(),
    'url_resolved': stream.toString(),
    'homepage': website?.toString() ?? '',
  });
}
