import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('streambeat/background_task');

bool get _needsBackgroundTask =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Ejecuta [body] pidiendo a iOS tiempo extra en segundo plano.
///
/// Al pasar a la siguiente cancion hay unos segundos sin audio mientras se
/// resuelve y arranca la nueva fuente. iOS suspende una app de audio en
/// segundo plano en cuanto deja de sonar, asi que sin esta tarea la siguiente
/// cancion solo empezaba al volver a abrir la app.
Future<T> withBackgroundTime<T>(Future<T> Function() body) async {
  if (!_needsBackgroundTask) return body();

  await _invoke('begin');
  try {
    return await body();
  } finally {
    await _invoke('end');
  }
}

Future<void> _invoke(String method) async {
  try {
    await _channel.invokeMethod<void>(method);
  } on MissingPluginException {
    // Pruebas y motores sin el canal nativo: no hay nada que pedir.
  } on PlatformException catch (error) {
    debugPrint('Background task $method failed: $error');
  }
}
