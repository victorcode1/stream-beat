import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

final RemoteAudioProxy remoteAudioProxy = RemoteAudioProxy();

/// Renueva las conexiones salientes tras volver de segundo plano.
void refreshRemoteAudioConnections() => remoteAudioProxy.refreshConnections();

Future<String> prepareRemoteAudioUrl({
  required String url,
  Map<String, String> requestHeaders = const {},
  String? mimeType,
  int? contentLength,
}) {
  return remoteAudioProxy.register(
    url: url,
    requestHeaders: requestHeaders,
    mimeType: mimeType,
    contentLength: contentLength,
  );
}

/// Expone un stream remoto como una URL local compatible con AVPlayer.
///
/// YouTube entrega URLs firmadas sin extension que requieren cabeceras HTTP.
/// `audioplayers` no permite adjuntar esas cabeceras y AVPlayer suele rechazar
/// URLs sin extension. Este proxy solo reenvia los bytes que el reproductor
/// solicita (incluidos rangos), por lo que no descarga la cancion completa
/// antes de empezar a reproducirla.
class RemoteAudioProxy {
  HttpServer? _server;

  /// Un solo cliente para todas las peticiones de AVPlayer: conserva las
  /// conexiones con googlevideo abiertas entre rangos. Abrir una por rango
  /// costaba un apreton de manos TLS (cientos de ms en datos moviles) en cada
  /// peticion y en cada salto dentro de la cancion.
  HttpClient? _client;

  HttpClient get _upstreamClient => _client ??= HttpClient()
    ..autoUncompress = false
    ..idleTimeout = const Duration(seconds: 30)
    ..maxConnectionsPerHost = 6;
  int _nextSourceId = 0;
  static const _maxSources = 4;
  final Map<String, _RemoteAudioSource> _sources = {};

  Future<String> register({
    required String url,
    Map<String, String> requestHeaders = const {},
    String? mimeType,
    int? contentLength,
  }) async {
    final remoteUri = Uri.tryParse(url);
    if (remoteUri == null || !remoteUri.hasScheme) return url;

    final server = await _ensureServer();
    final token = '${DateTime.now().microsecondsSinceEpoch}-${_nextSourceId++}';
    // La cancion actual y la siguiente de la cola nativa conviven: registrar
    // la siguiente no debe invalidar la que esta sonando.
    while (_sources.length >= _maxSources) {
      _sources.remove(_sources.keys.first);
    }
    _sources[token] = _RemoteAudioSource(
      uri: remoteUri,
      requestHeaders: Map.unmodifiable(requestHeaders),
      contentLength:
          contentLength ??
          int.tryParse(remoteUri.queryParameters['clen'] ?? ''),
    );

    final extension = _extensionForMimeType(mimeType);
    return Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      path: '/$token.$extension',
    ).toString();
  }

  /// Deja que las conexiones con googlevideo en curso terminen, pero las
  /// peticiones nuevas abren conexiones frescas. Mientras la app estuvo
  /// suspendida, las conexiones guardadas pudieron cerrarse por el otro lado y
  /// reutilizarlas hacia fallar la siguiente cancion.
  void refreshConnections() {
    _client?.close();
    _client = null;
  }

  Future<HttpServer> _ensureServer() async {
    final existing = _server;
    if (existing != null && await _isListening(existing)) return existing;
    if (existing != null) {
      debugPrint('Remote audio proxy socket was reclaimed; rebinding');
      _server = null;
      unawaited(existing.close(force: true).catchError((Object _) {}));
    }

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.autoCompress = false;
    _server = server;
    unawaited(
      server
          .forEach(_handleRequest)
          .catchError((Object error, StackTrace _) {
            debugPrint('Remote audio proxy stopped: $error');
          })
          .whenComplete(() {
            if (identical(_server, server)) _server = null;
          }),
    );
    return server;
  }

  /// iOS cierra los sockets que escuchan cuando suspende la app (TN2277), sin
  /// avisar al `HttpServer`. Una conexion local de prueba detecta ese caso
  /// antes de entregar a AVPlayer una URL que nunca responderia.
  Future<bool> _isListening(HttpServer server) async {
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        server.port,
        timeout: const Duration(milliseconds: 500),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleRequest(HttpRequest localRequest) async {
    final localResponse = localRequest.response;
    final method = localRequest.method.toUpperCase();
    final requestedRange = localRequest.headers.value(HttpHeaders.rangeHeader);
    debugPrint('Remote audio proxy request: $method range=$requestedRange');
    if (method != 'GET' && method != 'HEAD') {
      localResponse.statusCode = HttpStatus.methodNotAllowed;
      await localResponse.close();
      return;
    }

    final token = _tokenFromPath(localRequest.uri.pathSegments);
    final source = token == null ? null : _sources[token];
    if (source == null) {
      localResponse.statusCode = HttpStatus.notFound;
      await localResponse.close();
      return;
    }

    final byteRange = _ByteRange.parse(requestedRange);
    final useQueryRange =
        method == 'GET' &&
        byteRange != null &&
        _usesYoutubeQueryRange(source.uri);
    final upstreamUri = useQueryRange
        ? _uriWithRange(
            source.uri,
            byteRange,
            contentLength: source.contentLength,
          )
        : source.uri;

    try {
      final upstreamRequest = await _upstreamClient.openUrl(
        method,
        upstreamUri,
      );
      final upstreamHost = upstreamRequest.headers.value(
        HttpHeaders.hostHeader,
      );
      upstreamRequest.headers.clear();
      upstreamRequest.headers.set(HttpHeaders.contentLengthHeader, '0');
      localRequest.headers.forEach((name, values) {
        final normalizedName = name.toLowerCase();
        if (normalizedName != HttpHeaders.hostHeader &&
            (!useQueryRange ||
                (normalizedName != HttpHeaders.rangeHeader &&
                    normalizedName != 'if-range'))) {
          upstreamRequest.headers.set(name, values.join(', '));
        }
      });
      // Las cabeceras de la fuente tienen prioridad sobre las que AVPlayer
      // envia al servidor local (User-Agent, Cookie, etc.).
      for (final header in source.requestHeaders.entries) {
        upstreamRequest.headers.set(header.key, header.value);
      }
      if (upstreamHost != null) {
        upstreamRequest.headers.set(HttpHeaders.hostHeader, upstreamHost);
      }
      upstreamRequest.maxRedirects = 20;

      final upstreamResponse = await upstreamRequest.close();
      debugPrint(
        'Remote audio proxy upstream: ${upstreamResponse.statusCode} '
        'mode=${useQueryRange ? 'query' : 'header'} '
        'range=${upstreamResponse.headers.value(HttpHeaders.contentRangeHeader)} '
        'length=${upstreamResponse.contentLength} '
        'type=${upstreamResponse.headers.value(HttpHeaders.contentTypeHeader)}',
      );
      localResponse.headers.clear();
      upstreamResponse.headers.forEach((name, values) {
        final safeValues = values
            .map((value) => value.replaceAll(RegExp(r'[^\x09\x20-\x7F]'), '?'))
            .toList(growable: false);
        localResponse.headers.set(name, safeValues);
      });
      final successfulQueryRange =
          useQueryRange &&
          upstreamResponse.statusCode >= 200 &&
          upstreamResponse.statusCode < 300;
      if (successfulQueryRange) {
        final responseRange = byteRange.resolve(
          contentLength: source.contentLength,
          responseLength: upstreamResponse.contentLength,
        );
        localResponse.statusCode = HttpStatus.partialContent;
        localResponse.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        localResponse.headers.set(
          HttpHeaders.contentRangeHeader,
          responseRange.contentRangeHeader(source.contentLength),
        );
        if (responseRange.length != null) {
          localResponse.contentLength = responseRange.length!;
        }
      } else {
        localResponse.statusCode = upstreamResponse.statusCode;
      }
      localResponse.bufferOutput = false;

      if (method == 'HEAD') {
        await upstreamResponse.drain<void>();
      } else {
        // `addStream` respeta la contrapresion: si AVPlayer deja de leer,
        // pausa la descarga en vez de acumular la cancion en memoria. Si el
        // reproductor cierra la peticion, se cancela y se libera la conexion.
        await localResponse.addStream(upstreamResponse);
      }
      await localResponse.close();
    } catch (error) {
      debugPrint('Remote audio proxy request failed: $error');
      try {
        localResponse.statusCode = HttpStatus.badGateway;
        await localResponse.close();
      } catch (_) {
        // El reproductor cerro la solicitud al cambiar de cancion.
      }
    }
  }

  Future<void> close() async {
    _sources.clear();
    _client?.close(force: true);
    _client = null;
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }
}

class _RemoteAudioSource {
  const _RemoteAudioSource({
    required this.uri,
    required this.requestHeaders,
    required this.contentLength,
  });

  final Uri uri;
  final Map<String, String> requestHeaders;
  final int? contentLength;
}

class _ByteRange {
  const _ByteRange(this.start, this.end);

  final int start;
  final int? end;

  int? get length => end == null ? null : end! - start + 1;

  static _ByteRange? parse(String? value) {
    if (value == null || value.isEmpty) return null;
    final match = RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(value);
    if (match == null) return null;
    final start = int.tryParse(match.group(1)!);
    final rawEnd = match.group(2)!;
    final end = rawEnd.isEmpty ? null : int.tryParse(rawEnd);
    if (start == null || (end != null && end < start)) return null;
    return _ByteRange(start, end);
  }

  _ByteRange resolve({int? contentLength, int? responseLength}) {
    if (end != null) return this;
    if (contentLength != null && contentLength > start) {
      return _ByteRange(start, contentLength - 1);
    }
    if (responseLength != null && responseLength > 0) {
      return _ByteRange(start, start + responseLength - 1);
    }
    return this;
  }

  String contentRangeHeader(int? contentLength) {
    final resolvedEnd = end?.toString() ?? '*';
    final total = contentLength?.toString() ?? '*';
    return 'bytes $start-$resolvedEnd/$total';
  }
}

bool _usesYoutubeQueryRange(Uri uri) {
  final client = uri.queryParameters['c'];
  return client != null && client.toUpperCase() != 'ANDROID';
}

Uri _uriWithRange(Uri uri, _ByteRange range, {required int? contentLength}) {
  final end =
      range.end ??
      (contentLength != null && contentLength > range.start
          ? contentLength - 1
          : null);
  return uri.replace(
    queryParameters: {
      ...uri.queryParameters,
      'range': '${range.start}-${end?.toString() ?? ''}',
    },
  );
}

String? _tokenFromPath(List<String> pathSegments) {
  if (pathSegments.length != 1) return null;
  final fileName = pathSegments.single;
  final dot = fileName.lastIndexOf('.');
  if (dot <= 0) return null;
  return fileName.substring(0, dot);
}

String _extensionForMimeType(String? mimeType) {
  final normalized = mimeType?.toLowerCase() ?? '';
  if (normalized.startsWith('video/mp4')) return 'mp4';
  if (normalized.contains('mp4') ||
      normalized.contains('m4a') ||
      normalized.contains('aac')) {
    return 'm4a';
  }
  if (normalized.contains('webm') || normalized.contains('opus')) {
    return 'webm';
  }
  if (normalized.contains('mpeg') || normalized.contains('mp3')) return 'mp3';
  return 'audio';
}
