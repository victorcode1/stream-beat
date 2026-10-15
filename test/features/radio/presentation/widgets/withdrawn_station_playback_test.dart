import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/data/repositories/radio_browser_repository.dart';
import 'package:flow_music/features/radio/data/station_removals_repository.dart';
import 'package:flow_music/features/radio/presentation/controllers/radio_queue_controller.dart';
import 'package:flow_music/features/radio/presentation/utils/play_radio_station.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('withdrawn playback shows a notice before touching player or queue', (
    tester,
  ) async {
    final removals = StationRemovalsRepository(
      client: MockClient(
        (_) async => http.Response(
          '{"version":1,"updatedAt":"2026-10-15T00:00:00Z","stationUuids":["blocked"],"streamHosts":[]}',
          200,
        ),
      ),
      readCache: () => null,
      writeCache: (_) async {},
      loadAsset: () async =>
          '{"version":1,"updatedAt":"1970-01-01T00:00:00Z","stationUuids":[],"streamHosts":[]}',
    );
    // Load the HTTP fixture before tapping the playback action.
    await removals.load();
    final repository = RadioBrowserRepository(removalsRepository: removals);
    addTearDown(repository.close);
    final station = RadioStation.fromJson({
      'stationuuid': 'blocked',
      'name': 'Blocked radio',
      'url': 'https://radio.test/live',
    });
    bool? result;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () async {
                  result = await playRadioStation(
                    context: context,
                    ref: ref,
                    station: station,
                    queue: [station],
                    index: 0,
                    repository: repository,
                  );
                },
                child: const Text('Play'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Play'));
    await tester.pump();
    expect(result, isFalse);
    expect(find.text(LocaleKeys.station_unavailable), findsOneWidget);
    expect(container.read(radioQueueControllerProvider).stations, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
