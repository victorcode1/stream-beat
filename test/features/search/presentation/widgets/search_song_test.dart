import 'package:flow_music/features/search/presentation/widgets/search_song.dart';
import 'package:flow_music/features/search/presentation/pages/list_search.dart';
import 'package:flow_music/features/song/presentation/pages/song.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('submitted queries render a results list instead of a player', (
    tester,
  ) async {
    final delegate = ViewSearchDelegate()..query = 'previous search';
    late Widget results;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            results = delegate.buildResults(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(results, isA<SuggestedListSearch>());
    expect(results, isNot(isA<SongWidget>()));
    expect((results as SuggestedListSearch).searchQuery, 'previous search');
    delegate.dispose();
  });
}
