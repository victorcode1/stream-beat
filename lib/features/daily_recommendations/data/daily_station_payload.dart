import 'dart:convert';

import 'package:flow_music/features/radio/data/models/radio_station.dart';

class DailyStationPayload {
  const DailyStationPayload._();

  static String encode(RadioStation station) {
    return jsonEncode({
      'v': 1,
      'station': {
        'stationuuid': station.stationUuid,
        'name': station.name,
        'url': station.url,
        'url_resolved': station.urlResolved,
        'homepage': station.homepage,
        'favicon': station.favicon,
        'country': station.country,
        'countrycode': station.countryCode,
        'language': station.language,
        'codec': station.codec,
        'bitrate': station.bitrate,
        'lastcheckok': station.lastCheckOk,
        'hls': station.hls,
        'ssl_error': station.sslError,
        'geo_lat': station.latitude,
        'geo_long': station.longitude,
      },
    });
  }

  static RadioStation? decode(String? payload) {
    if (payload == null || payload.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic> || decoded['v'] != 1) return null;
      final stationJson = decoded['station'];
      if (stationJson is! Map) return null;
      final station = RadioStation.fromJson(
        Map<String, dynamic>.from(stationJson),
      );
      if (station.name.trim().isEmpty || !station.isPlayable) return null;
      return station;
    } catch (_) {
      return null;
    }
  }
}
