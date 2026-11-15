import 'dart:convert';
import 'dart:io';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:flow_music/features/favorites/data/favorites_repository.dart';
import 'package:flow_music/features/song/presentation/controllers/audio_download_writer_io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('download-metadata-test');
    Hive.init('${root.path}/hive');
    await Hive.openBox(favoritesBoxName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => root.path,
        );
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });

  test(
    'orphan downloads recover from favorites and persist without downloading bytes',
    () async {
      final dir = await Directory('${root.path}/downloads').create();
      final audio = File('${dir.path}/RHSQDLgHNoU.m4a');
      await audio.writeAsBytes([1, 2, 3]);
      await Hive.box(favoritesBoxName).put(
        'RHSQDLgHNoU',
        jsonEncode({
          'videoId': 'RHSQDLgHNoU',
          'title': 'Recovered song',
          'author': 'Saved artist',
          'thumbnailUrl': 'https://example.com/saved.jpg',
          'addedAt': '2026-11-13T10:00:00Z',
        }),
      );
      final first = (await listDownloadedAudios()).single;
      expect(first.videoId, 'RHSQDLgHNoU');
      expect(first.title, 'Recovered song');
      expect(first.author, 'Saved artist');
      expect(first.thumbnailUrl, 'https://example.com/saved.jpg');
      await Hive.box(favoritesBoxName).clear();
      expect((await listDownloadedAudios()).single.title, 'Recovered song');
      expect(await audio.readAsBytes(), [1, 2, 3]);
    },
  );

  test(
    'moved documents keep title artist and artwork from the sidecar',
    () async {
      final dir = await Directory('${root.path}/downloads').create();
      await File('${dir.path}/RHSQDLgHNoU.m4a').writeAsBytes([1, 2, 3]);
      await File('${dir.path}/RHSQDLgHNoU-audio.json').writeAsString(
        jsonEncode({
          'videoId': 'RHSQDLgHNoU',
          'title': 'Saved song',
          'author': 'Artist',
          'thumbnailUrl': 'https://example.com/art.jpg',
          'filePath': '/old-ios-container/downloads/RHSQDLgHNoU.m4a',
          'downloadedAt': '2026-11-13T10:00:00Z',
        }),
      );
      final downloads = await listDownloadedAudios();
      expect(downloads, hasLength(1));
      expect(downloads.single.title, 'Saved song');
      expect(downloads.single.author, 'Artist');
      expect(downloads.single.thumbnailUrl, 'https://example.com/art.jpg');
      expect(downloads.single.filePath, '${dir.path}/RHSQDLgHNoU.m4a');
    },
  );
}
