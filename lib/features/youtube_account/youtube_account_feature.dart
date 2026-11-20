import 'package:flutter/foundation.dart';

/// La cuenta de YouTube Music se puede apagar al compilar con
/// `--dart-define=STREAMBEAT_YT_ACCOUNT=false`. El APK publico sale asi: la
/// sesion de Google por cookie es solo para las builds internas (TestFlight).
const bool _youtubeAccountEnabled = bool.fromEnvironment(
  'STREAMBEAT_YT_ACCOUNT',
  defaultValue: true,
);

/// Si la app ofrece la cuenta. En web nunca: el navegador no deja enviar la
/// cookie de sesion.
bool get youtubeAccountAvailable => _youtubeAccountEnabled && !kIsWeb;
