import 'dart:io';

import 'package:flow_music/features/radio/data/custom_station.dart';
import 'package:flow_music/features/radio/data/radio_favorites_repository.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  test('validates required name and HTTP(S) stream without userinfo', () {
    for (final url in [
      '',
      'file:///music',
      'ftp://host/live',
      'https://user:pass@host/live',
      'https://user@host',
      'https://@host',
      'https://bad host/live',
      'https:///',
    ]) {
      expect(
        () => createCustomStation(name: 'Radio', streamUrl: url),
        throwsFormatException,
        reason: 'stream URL: $url',
      );
    }
    expect(
      () => createCustomStation(name: '  ', streamUrl: 'https://host/live'),
      throwsFormatException,
    );
    expect(
      () => createCustomStation(
        name: 'Radio',
        streamUrl: 'https://host/live',
        homepage: 'javascript:alert(1)',
      ),
      throwsFormatException,
    );
  });

  test('creates unique custom IDs, trims fields, and round trips JSON', () {
    final first = createCustomStation(
      name: ' My radio ',
      streamUrl: ' http://host/live ',
      homepage: ' https://host/ ',
    );
    final second = createCustomStation(
      name: 'My radio',
      streamUrl: 'https://host/live',
    );
    expect(first.isCustomStation, isTrue);
    expect(first.stationUuid, startsWith('custom-'));
    expect(first.stationUuid, isNot(second.stationUuid));
    expect(first.name, 'My radio');
    expect(first.streamUrl, 'http://host/live');
    expect(first.homepage, 'https://host/');
    expect(
      RadioStation.fromJson(first.toJson()).stationUuid,
      first.stationUuid,
    );
    expect(second.homepage, isEmpty);
  });

  test(
    'custom stations persist in existing favorites and can be deleted',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'custom-station-test-',
      );
      Hive.init(directory.path);
      var box = await Hive.openBox(radioFavoritesBoxName);
      addTearDown(() async {
        await box.close();
        await directory.delete(recursive: true);
      });
      const repository = RadioFavoritesRepository();
      final station = createCustomStation(
        name: 'Local radio',
        streamUrl: 'https://host/live',
      );
      await repository.toggle(station);
      await box.close();
      box = await Hive.openBox(radioFavoritesBoxName);
      expect(repository.readAll().single.isCustomStation, isTrue);
      expect(repository.readAll().single.name, 'Local radio');
      await repository.remove(station.stationUuid);
      expect(repository.readAll(), isEmpty);
    },
  );
}
