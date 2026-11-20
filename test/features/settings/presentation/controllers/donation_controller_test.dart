import 'package:flow_music/features/settings/presentation/controllers/donation_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  const controller = DonationController();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('opens the public StreamBeat Music profile outside the app', () async {
    MethodCall? launched;
    messenger.setMockMethodCallHandler(channel, (call) async {
      launched = call;
      return true;
    });

    expect(await controller.openDonationPage(), isTrue);
    expect(launched?.method, 'launch');
    expect(launched?.arguments['url'], 'https://ko-fi.com/streambeat');
    expect(launched?.arguments['useSafariVC'], isFalse);
    expect(launched?.arguments['useWebView'], isFalse);
  });

  test('reports failure when no browser can open the page', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => false);

    expect(await controller.openDonationPage(), isFalse);
  });

  test('handles a platform error without crashing settings', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'launch_failed');
    });

    expect(await controller.openDonationPage(), isFalse);
  });
}
