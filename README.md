# StreamBeat

Aplicación Flutter para descubrir música, reproducir audio y explorar estaciones de radio internacionales.

## Datos y privacidad

StreamBeat Music (`main`) es una app de uso interno: no tiene cuentas,
publicidad ni pagos, y todo funciona de forma local:

- Favoritos, playlists, historial y preferencias se guardan solamente en el dispositivo con Hive. No se respaldan ni se sincronizan entre dispositivos.
- Las descargas, el audio sin conexión y la caché se guardan en archivos locales del dispositivo.
- La ubicación se solicita solo mientras la app está abierta, para elegir el país de las recomendaciones y centrar el explorador de radio. No se guarda ni se envía a un servidor.

La rama main conserva las funciones de búsqueda y reproducción basadas en YouTube. La rama store se prepara como una experiencia centrada únicamente en estaciones de radio.

## Identidad independiente de main

- `main`: `com.victorflores.streambeatmusic` (StreamBeat Music en Android/iOS).
- `store`: conserva `com.victorflores.streambeat` en Android/iOS.

Los cambios de la antigua rama de trabajo `dev-main` están integrados en `main`.
Las nuevas ramas de trabajo de StreamBeat Music deben partir de `main`.

Android, iOS y macOS usan el nuevo identificador en todas las configuraciones;
Linux también tiene su propio application ID. En Android/iOS se pueden instalar
ambas apps a la vez y cada una mantiene sus datos locales.
Al integrar cambios futuros entre ramas, conservar la identidad de la rama destino.

Para instalar en un iPhone físico o distribuir, configurar la firma del bundle
ID en Apple. En web, usar un origen/puerto y configuración propios para aislar el almacenamiento.

## Requisitos

- Flutter SDK 3.8 o posterior
- Xcode con Swift Package Manager para iOS o macOS
- Android SDK para Android

## Ejecutar

    flutter pub get
    flutter run

Para generar los archivos de Riverpod y Freezed:

    dart run build_runner build --delete-conflicting-outputs

## Compilación

    flutter build appbundle --release
    flutter build ipa --release

## Funcionalidades en main

- Búsqueda y reproducción de música
- Recomendaciones por país
- Radios internacionales y explorador de radio
- Reproducción en segundo plano
- Favoritos, playlists y ajustes locales

## Aviso sobre contenido de terceros

Las marcas, catálogos y emisiones pertenecen a sus respectivos titulares. Antes de publicar una versión en una tienda, confirma que cada fuente de audio y su forma de reproducción cumplen los términos de servicio y las licencias aplicables.
