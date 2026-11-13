import 'dart:io';

import 'package:flow_music/core/audio/remote_audio_proxy_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer upstreamServer;
  late HttpClient client;
  late RemoteAudioProxy proxy;
  String? receivedAuthorization;
  String? receivedRange;
  String? receivedQueryRange;

  const audioBytes = <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

  setUp(() async {
    receivedAuthorization = null;
    receivedRange = null;
    receivedQueryRange = null;
    client = HttpClient();
    proxy = RemoteAudioProxy();
    upstreamServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    upstreamServer.listen((request) async {
      receivedAuthorization = request.headers.value(
        HttpHeaders.authorizationHeader,
      );
      receivedRange = request.headers.value(HttpHeaders.rangeHeader);
      receivedQueryRange = request.uri.queryParameters['range'];

      var first = 0;
      var last = audioBytes.length - 1;
      final match = RegExp(
        r'^(?:bytes=)?(\d+)-(\d+)$',
      ).firstMatch(receivedRange ?? receivedQueryRange ?? '');
      if (match != null) {
        first = int.parse(match.group(1)!);
        last = int.parse(match.group(2)!);
        if (receivedRange != null) {
          request.response
            ..statusCode = HttpStatus.partialContent
            ..headers.set(
              HttpHeaders.contentRangeHeader,
              'bytes $first-$last/${audioBytes.length}',
            );
        }
      }

      final body = audioBytes.sublist(first, last + 1);
      request.response
        ..headers.set(HttpHeaders.acceptRangesHeader, 'bytes')
        ..headers.contentType = ContentType('audio', 'mp4')
        ..contentLength = body.length
        ..add(body);
      await request.response.close();
    });
  });

  tearDown(() async {
    client.close(force: true);
    await proxy.close();
    await upstreamServer.close(force: true);
  });

  test(
    'forwards auth and byte ranges without buffering the full audio',
    () async {
      final localUrl = await proxy.register(
        url:
            'http://${upstreamServer.address.address}:${upstreamServer.port}/stream',
        requestHeaders: const {
          HttpHeaders.authorizationHeader: 'Bearer stream-token',
        },
        mimeType: 'audio/mp4',
      );

      expect(Uri.parse(localUrl).path, endsWith('.m4a'));

      final request = await client.getUrl(Uri.parse(localUrl));
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=3-5');
      final response = await request.close();
      final body = await response.fold<List<int>>(
        <int>[],
        (bytes, chunk) => bytes..addAll(chunk),
      );

      expect(response.statusCode, HttpStatus.partialContent);
      expect(
        response.headers.value(HttpHeaders.contentRangeHeader),
        'bytes 3-5/10',
      );
      expect(body, [3, 4, 5]);
      expect(receivedAuthorization, 'Bearer stream-token');
      expect(receivedRange, 'bytes=3-5');
    },
  );

  test(
    'translates WEB client ranges to the googlevideo query parameter',
    () async {
      final localUrl = await proxy.register(
        url:
            'http://${upstreamServer.address.address}:${upstreamServer.port}/stream?c=WEB',
        mimeType: 'audio/mp4',
        contentLength: audioBytes.length,
      );

      final probeRequest = await client.getUrl(Uri.parse(localUrl));
      probeRequest.headers.set(HttpHeaders.rangeHeader, 'bytes=0-1');
      final probeResponse = await probeRequest.close();
      await probeResponse.drain<void>();

      expect(probeResponse.statusCode, HttpStatus.partialContent);
      expect(
        probeResponse.headers.value(HttpHeaders.contentRangeHeader),
        'bytes 0-1/10',
      );
      expect(receivedRange, isNull);
      expect(receivedQueryRange, '0-1');

      final fullRequest = await client.getUrl(Uri.parse(localUrl));
      fullRequest.headers.set(HttpHeaders.rangeHeader, 'bytes=0-9');
      final fullResponse = await fullRequest.close();
      final body = await fullResponse.fold<List<int>>(
        <int>[],
        (bytes, chunk) => bytes..addAll(chunk),
      );

      expect(fullResponse.statusCode, HttpStatus.partialContent);
      expect(
        fullResponse.headers.value(HttpHeaders.contentRangeHeader),
        'bytes 0-9/10',
      );
      expect(receivedRange, isNull);
      expect(receivedQueryRange, '0-9');
      expect(body, audioBytes);
    },
  );

  test('keeps a real mp4 extension for muxed Apple playback', () async {
    final localUrl = await proxy.register(
      url:
          'http://${upstreamServer.address.address}:${upstreamServer.port}/stream',
      mimeType: 'video/mp4',
    );

    expect(Uri.parse(localUrl).path, endsWith('.mp4'));
  });

  test('keeps the playing URL valid when the next song is queued', () async {
    String upstream(String path) =>
        'http://${upstreamServer.address.address}:${upstreamServer.port}/$path';
    Future<int> statusOf(String url) async {
      final response = await (await client.getUrl(Uri.parse(url))).close();
      await response.drain<void>();
      return response.statusCode;
    }

    final playingUrl = await proxy.register(
      url: upstream('playing'),
      mimeType: 'audio/mp4',
    );
    await proxy.register(url: upstream('next'), mimeType: 'audio/mp4');

    // La cancion que suena sigue disponible aunque la siguiente ya este en la
    // cola nativa.
    expect(await statusOf(playingUrl), HttpStatus.ok);

    // Las fuentes viejas se descartan para no acumularlas sin limite.
    for (var i = 0; i < 4; i++) {
      await proxy.register(url: upstream('later-$i'), mimeType: 'audio/mp4');
    }
    expect(await statusOf(playingUrl), HttpStatus.notFound);
  });
}
