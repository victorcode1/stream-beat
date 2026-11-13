import 'package:flutter/foundation.dart';

/// En iOS y macOS StreamBeat funciona como un reproductor: no ofrece un
/// catálogo propio de emisoras. El usuario busca en el directorio público
/// radio-browser.info o agrega la URL de un stream, y solo entonces se piden
/// emisoras (App Review, guía 5.2.3). Android conserva la portada con
/// sugerencias.
bool get stationDirectoryIsSearchFirst =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);
