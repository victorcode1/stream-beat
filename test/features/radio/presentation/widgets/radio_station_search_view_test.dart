import 'package:flow_music/features/home/presentation/providers/text_search.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/data/repositories/radio_browser_repository.dart';
import 'package:flow_music/features/radio/presentation/widgets/radio_station_search_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  testWidgets('reloads results after typing without returning a Future', (
    tester,
  ) async {
    final controller = TextEditingController();
    final repository = _FakeRadioBrowserRepository();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [searchProvider.overrideWithValue(controller)],
        child: MaterialApp(
          home: Scaffold(body: RadioStationSearchView(repository: repository)),
        ),
      ),
    );
    await tester.pump();

    controller.text = 'la mega';
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(repository.lastName, 'la mega');
  });

  testWidgets('on iOS waits for a search instead of listing top stations', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final controller = TextEditingController();
    final repository = _FakeRadioBrowserRepository();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [searchProvider.overrideWithValue(controller)],
        child: MaterialApp(
          home: Scaffold(body: RadioStationSearchView(repository: repository)),
        ),
      ),
    );
    await tester.pump();

    expect(repository.topStationsCalls, 0);
    expect(find.byIcon(Icons.travel_explore_rounded), findsOneWidget);

    controller.text = 'la mega';
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(repository.lastName, 'la mega');
    debugDefaultTargetPlatformOverride = null;
  });
}

class _FakeRadioBrowserRepository extends RadioBrowserRepository {
  String? lastName;
  int topStationsCalls = 0;

  @override
  Future<List<RadioStation>> topStations({int limit = 30}) async {
    topStationsCalls++;
    return [];
  }

  @override
  Future<List<RadioStation>> searchStations({
    String name = '',
    String tag = '',
    String countryCode = '',
    int limit = 30,
  }) async {
    lastName = name;
    return [];
  }
}
