import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/settings/presentation/pages/station_rights_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in ['es', 'en', 'pt-BR']) {
    testWidgets('rights content is readable on a small screen ($locale)', (
      tester,
    ) async {
      final strings =
          jsonDecode(
                File('assets/translations/$locale.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      Localization.load(
        locale == 'pt-BR' ? const Locale('pt', 'BR') : Locale(locale),
        translations: Translations(strings),
      );
      addTearDown(() => Localization.load(const Locale('en')));
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: StationRightsPage()));
      expect(
        find.text(strings[LocaleKeys.station_rights_title] as String),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text(strings[LocaleKeys.station_broadcasters] as String),
        150,
      );
      expect(
        find.text(strings[LocaleKeys.station_report_removal] as String),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'settings entry opens rights screen with directory and removal actions',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: StationRightsEntry())),
      );
      await tester.tap(find.text(LocaleKeys.station_rights_title));
      await tester.pumpAndSettle();
      expect(find.byType(StationRightsPage), findsOneWidget);
      expect(find.text('Radio Browser'), findsOneWidget);
      expect(find.text(LocaleKeys.station_rights_streams), findsOneWidget);
      expect(find.text(LocaleKeys.station_rights_owners), findsOneWidget);
      expect(find.text(LocaleKeys.station_rights_removal), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(LocaleKeys.station_report_removal),
        150,
      );
      expect(find.text(LocaleKeys.station_report_removal), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(LocaleKeys.station_broadcasters),
        150,
      );
      expect(find.text(LocaleKeys.station_broadcasters), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(StationRightsEntry), findsOneWidget);
    },
  );

  testWidgets('directory attribution opens rights screen', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StationDirectoryAttribution())),
    );
    await tester.tap(find.text(LocaleKeys.station_directory_attribution));
    await tester.pumpAndSettle();
    expect(find.byType(StationRightsPage), findsOneWidget);
  });
}
