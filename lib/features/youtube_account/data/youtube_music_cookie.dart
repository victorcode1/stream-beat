import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Sesion de YouTube Music tomada del encabezado `Cookie` del navegador.
///
/// YouTube firma las peticiones de una sesion iniciada con
/// `SAPISIDHASH <segundos>_<sha1("<segundos> <SAPISID> <origen>")>`, asi que
/// basta con la cookie `SAPISID` (o su gemela `__Secure-3PAPISID`).
class YouTubeMusicCookie {
  const YouTubeMusicCookie._(this.header, this._sapisid);

  static const origin = 'https://music.youtube.com';

  /// Encabezado `Cookie` tal como se envia.
  final String header;
  final String _sapisid;

  /// Lee lo que pego el usuario. Acepta el encabezado solo o con el prefijo
  /// `Cookie:`. Devuelve null si falta la cookie que firma la sesion.
  static YouTubeMusicCookie? tryParse(String raw) {
    final header = raw
        .replaceFirst(RegExp(r'^\s*cookie\s*:', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\r\n]+'), '')
        .trim();
    if (header.isEmpty) return null;

    final values = <String, String>{};
    for (final part in header.split(';')) {
      final separator = part.indexOf('=');
      if (separator <= 0) continue;
      final name = part.substring(0, separator).trim();
      final value = part.substring(separator + 1).trim();
      if (name.isNotEmpty && value.isNotEmpty) values[name] = value;
    }

    final sapisid = values['SAPISID'] ?? values['__Secure-3PAPISID'];
    if (sapisid == null) return null;
    return YouTubeMusicCookie._(header, sapisid);
  }

  /// Valor del encabezado `Authorization` para el instante [now]. La firma
  /// incluye el sitio que hace la peticion ([site]).
  String authorization(DateTime now, {String site = origin}) {
    final seconds = now.millisecondsSinceEpoch ~/ 1000;
    final digest = sha1.convert(utf8.encode('$seconds $_sapisid $site'));
    return 'SAPISIDHASH ${seconds}_$digest';
  }

  /// Encabezados que convierten una peticion a la API interna de [site]
  /// (YouTube Music o YouTube) en una de la sesion iniciada.
  Map<String, String> sessionHeaders(String site, DateTime now) => {
    'origin': site,
    'x-origin': site,
    'x-goog-authuser': '0',
    'cookie': header,
    'authorization': authorization(now, site: site),
  };
}
