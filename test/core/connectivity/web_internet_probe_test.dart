import 'package:flow_music/core/connectivity/web_internet_probe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final appUri = Uri.parse('https://streambeat-music.vercel.app/#/settings');

  test(
    'checks the app origin with a fresh HEAD request instead of CORS probes',
    () async {
      Uri? requestedUri;
      final online = await checkWebInternet(
        appUri: appUri,
        clientFactory: () => MockClient((request) async {
          requestedUri = request.url;
          expect(request.method, 'HEAD');
          expect(request.followRedirects, isFalse);
          return http.Response('', 200);
        }),
      );

      expect(online, isTrue);
      expect(requestedUri?.origin, appUri.origin);
      expect(requestedUri?.path, '/version.json');
      expect(requestedUri?.fragment, isEmpty);
      expect(requestedUri?.queryParameters['connectivity'], isNotEmpty);
    },
  );

  for (final status in [302, 404, 503]) {
    test('does not accept HTTP $status as a working connection', () async {
      expect(
        await checkWebInternet(
          appUri: appUri,
          clientFactory: () =>
              MockClient((_) async => http.Response('', status)),
        ),
        isFalse,
      );
    });
  }

  test('reports offline when the network request fails', () async {
    expect(
      await checkWebInternet(
        appUri: appUri,
        clientFactory: () => MockClient((_) async {
          throw http.ClientException('Network unavailable');
        }),
      ),
      isFalse,
    );
  });
}
