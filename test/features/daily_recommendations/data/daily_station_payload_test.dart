import 'package:flow_music/features/daily_recommendations/data/daily_station_payload.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips the station needed to open a notification', () {
    final station = RadioStation.fromJson({
      'stationuuid': 'panama-radio',
      'name': 'Radio Panamá',
      'url': 'https://example.com/original',
      'homepage': 'https://example.com/',
      'url_resolved': 'https://example.com/live',
      'favicon': 'https://example.com/icon.png',
      'country': 'Panama',
      'countrycode': 'PA',
      'language': 'Spanish',
      'codec': 'MP3',
      'bitrate': 128,
      'lastcheckok': 1,
    });

    final decoded = DailyStationPayload.decode(
      DailyStationPayload.encode(station),
    );

    expect(decoded, isNotNull);
    expect(decoded!.stationUuid, 'panama-radio');
    expect(decoded.name, 'Radio Panamá');
    expect(decoded.homepage, 'https://example.com/');
    expect(decoded.streamUrl, 'https://example.com/live');
    expect(decoded.countryCode, 'PA');
    expect(decoded.bitrate, 128);
  });

  test('rejects malformed or unplayable payloads', () {
    expect(DailyStationPayload.decode(null), isNull);
    expect(DailyStationPayload.decode('not-json'), isNull);
    expect(
      DailyStationPayload.decode(
        '{"v":1,"station":{"name":"Broken","url":"file:///tmp/x"}}',
      ),
      isNull,
    );
  });
}
