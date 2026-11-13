import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Cliente de YouTube compartido por la reproduccion y el prefetch.
///
/// Crear un `YoutubeExplode` por cancion abria conexiones TLS nuevas con
/// youtube.com cada vez, algo que en datos moviles cuesta cientos de
/// milisegundos. Este cliente vive toda la sesion y reutiliza sus conexiones,
/// asi que nunca se cierra.
final YoutubeExplode sharedYoutubeExplode = YoutubeExplode();
