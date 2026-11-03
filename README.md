# StreamBeat

Aplicación Flutter para descubrir música, reproducir audio y explorar estaciones de radio internacionales.

## Datos y privacidad

La reproducción y las preferencias siguen funcionando de forma local. Las
funciones de monetización usan servicios desacoplados, sin cuenta de StreamBeat:

- Favoritos, playlists, historial y preferencias se guardan solo en el dispositivo con Hive y funcionan sin red. No hay respaldo remoto ni sincronización entre dispositivos; ninguna compra o suscripción la habilita. Los aportes de las tiendas solo quitan anuncios.
- La ubicación se solicita solo mientras la app está abierta, para elegir el país de las recomendaciones y centrar el explorador de radio. No se guarda ni se envía a un servidor.
- La recomendación diaria es opcional y se programa localmente a las 6:00 p. m. con una emisora aleatoria; no requiere un servidor ni ubicación en segundo plano.
- Las compilaciones `release` envían a Sentry errores y una muestra de trazas de rendimiento para diagnóstico. Sentry permanece desactivado en debug y profile, y la integración no envía información personal por defecto.
- RevenueCat valida los aportes, las compras anteriores y la restauración mediante Google Play Billing o Apple In-App Purchase.
- En Android, web y escritorio no Apple, «Aportar otro importe» abre Ko-fi en el navegador para apoyar voluntariamente desde US$1. Este apoyo externo no quita anuncios ni desbloquea funciones. El enlace permanece oculto en las compilaciones nativas de iOS y macOS.
- Desde esta versión la app no ejecuta la infraestructura ni las migraciones históricas de copia en la nube. Esta versión no borra por sí misma copias remotas guardadas antes ni retira la infraestructura remota.
- AdMob muestra como máximo un banner adaptable anclado a todo el ancho, separado de los controles, también durante la reproducción con la app en primer plano. Se oculta para usuarios Premium y libera el anuncio al pasar a segundo plano.

La rama main conserva las funciones de búsqueda y reproducción basadas en YouTube. La rama store se prepara como una experiencia centrada únicamente en estaciones de radio.

## Requisitos

- Flutter SDK 3.38.1 o posterior
- Xcode y CocoaPods para iOS o macOS
- Android SDK para Android

## Ejecutar

    flutter pub get
    flutter run

Para habilitar aportes, restauración de compras y anuncios usa el archivo de ejemplo en
`config/monetization.example.json`:

    cp config/monetization.example.json config/monetization.local.json
    flutter run --dart-define-from-file=config/monetization.local.json

La arquitectura, el esquema y el procedimiento de publicación están descritos
en `docs/MONETIZATION.md`.

Sentry ya está conectado al proyecto `streambeat` y solo se inicializa en
compilaciones `release`. `flutter run` y las compilaciones profile no envían
errores, trazas ni eventos. Las compilaciones release usan el entorno
`production` por defecto. Para cambiar el proyecto o el entorno de una
compilación release:

    flutter build ipa --release \
      --dart-define=SENTRY_DSN=https://TU_DSN \
      --dart-define=SENTRY_ENVIRONMENT=production \
      --dart-define=SENTRY_TRACES_SAMPLE_RATE=1.0

`SENTRY_TRACES_SAMPLE_RATE` acepta valores entre `0.0` y `1.0`. Si se omite,
usa `0.1`. Para desactivar también el envío en una compilación release, pasa
`--dart-define=SENTRY_DSN=`. Para ver logs internos del SDK durante una prueba
release, agrega `--dart-define=SENTRY_DEBUG=true`.

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
- Recomendación local diaria mediante notificación, con acceso directo a la emisora
- Flow Mix por estado de ánimo, personalizado localmente con historial, favoritos y feedback
- Favoritos, playlists y ajustes locales

## Aviso sobre contenido de terceros

Las marcas, catálogos y emisiones pertenecen a sus respectivos titulares. Antes de publicar una versión en una tienda, confirma que cada fuente de audio y su forma de reproducción cumplen los términos de servicio y las licencias aplicables.

## Herramientas de desarrollo

La configuración de CodeGraph y su uso local están en `docs/codegraph.md`.
La herramienta de compilación Android usa Gradle 9.1.0, AGP 9.0.1 y Kotlin
2.3.20; la integración está validada con Flutter 3.47.3 y Dart 3.13.3.
Para verificar las claves públicas y los identificadores antes de una compilación:

    dart run tool/verify_monetization_config.dart config/monetization.local.json
    dart run tool/verify_monetization_config.dart config/monetization.local.json --platform=ios

La validación iOS requiere macOS y comprueba también `ios/Runner/Info.plist`.
Estas comprobaciones no sustituyen la validación de compras en las tiendas.
