import 'dart:async';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Cliente de YouTube compartido por la reproduccion y el prefetch.
///
/// Crear un `YoutubeExplode` por cancion abria conexiones TLS nuevas con
/// youtube.com cada vez, algo que en datos moviles cuesta cientos de
/// milisegundos. Este cliente reutiliza sus conexiones durante la sesion.
YoutubeExplode get sharedYoutubeExplode => _client;

YoutubeExplode _client = YoutubeExplode();

/// Cambia a un cliente nuevo al volver de segundo plano: las conexiones que
/// guardaba pudieron cerrarse mientras la app estaba suspendida. El anterior
/// se cierra mas tarde para no cortar una resolucion que este en curso.
void refreshSharedYoutubeExplode() {
  final previous = _client;
  _client = YoutubeExplode();
  Timer(const Duration(seconds: 30), previous.close);
}
