import 'package:flow_music/core/connectivity/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offline banner retries when the button is pressed', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OfflineBannerContent(onRetry: () => retries++)),
      ),
    );

    expect(find.byKey(const Key('offline-banner')), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

    await tester.tap(find.byType(TextButton));
    expect(retries, 1);
  });
}
