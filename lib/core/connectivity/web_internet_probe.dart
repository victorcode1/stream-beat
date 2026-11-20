import 'package:http/http.dart' as http;
import 'package:internet_connection_monitor/internet_connection_monitor.dart';

/// Comprueba el servidor de la app sin depender de permisos CORS de terceros.
Future<bool> checkWebInternet({
  Uri? appUri,
  http.Client Function()? clientFactory,
}) async {
  final endpoint = (appUri ?? Uri.base)
      .resolve('version.json')
      .replace(
        queryParameters: {
          // Cada revisión debe llegar a la red, incluso con el service worker activo.
          'connectivity': DateTime.now().microsecondsSinceEpoch.toString(),
        },
      );
  final probe = HttpInternetProbe(
    endpoints: [
      InternetCheckEndpoint(endpoint, method: 'HEAD', expectedStatusCode: 200),
    ],
    clientFactory: clientFactory,
  );
  try {
    return await probe();
  } finally {
    probe.close();
  }
}
