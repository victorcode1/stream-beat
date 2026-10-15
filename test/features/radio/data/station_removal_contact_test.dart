import 'dart:convert';
import 'dart:io';

import 'package:flow_music/core/contact/developer_contact.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/data/station_removal_contact.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in ['es', 'en', 'pt-BR']) {
    test(
      'builds encoded mailto with station metadata and blank requester fields ($locale)',
      () {
        final strings =
            jsonDecode(
                  File('assets/translations/$locale.json').readAsStringSync(),
                )
                as Map<String, dynamic>;
        final station = RadioStation.fromJson({
          'name': 'Radio + Música & Noticias',
          'stationuuid': 'station-123',
          'url': 'https://radio.test/live?a=1&b=2',
          'country': 'Panamá',
        });
        final uri = buildStationRemovalMailto(
          station: station,
          subject: strings['station_removal_subject'] as String,
          bodyTemplate: strings['station_removal_body'] as String,
        );
        expect(uri.scheme, 'mailto');
        expect(uri.path, developerEmail);
        expect(uri.query, contains('%20'));
        expect(
          uri.queryParameters['subject'],
          strings['station_removal_subject'],
        );
        final body = uri.queryParameters['body']!;
        for (final field in [
          station.name,
          station.stationUuid,
          station.streamUrl,
          station.country,
        ]) {
          expect(body, contains(field));
        }
        expect(body, isNot(contains('{name}')));
        expect(body, contains(': \n'));
        final general = buildStationRemovalMailto(
          subject: strings['station_removal_subject'] as String,
          bodyTemplate: strings['station_removal_body'] as String,
        );
        expect(general.queryParameters['body'], isNot(contains('{uuid}')));
      },
    );
  }
}
