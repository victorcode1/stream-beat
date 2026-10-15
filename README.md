# StreamBeat

Aplicación Flutter para descubrir música, reproducir audio y explorar estaciones de radio internacionales.

## Datos y privacidad

La reproducción y las preferencias siguen funcionando de forma local. Las
funciones opcionales de cuenta y monetización usan servicios desacoplados:

- Favoritos, playlists, historial y preferencias se guardan solamente en el dispositivo con Hive. No se respaldan ni se sincronizan entre dispositivos; iniciar o cerrar sesión no borra estos datos locales.
- Las descargas, el audio sin conexión y la caché se guardan en archivos locales del dispositivo.
- La ubicación se solicita solo mientras la app está abierta, para elegir el país de las recomendaciones y centrar el explorador de radio. No se guarda ni se envía a un servidor.
- Supabase Auth y PostgreSQL conservan la cuenta y el perfil entre dispositivos.
- RevenueCat valida la suscripción mensual de USD 1 mediante Google Play Billing o Apple In-App Purchase.
- AdMob muestra como máximo un banner adaptativo; se oculta durante la reproducción y para suscriptores.

La rama main conserva las funciones de búsqueda y reproducción basadas en YouTube. La rama store se prepara como una experiencia centrada únicamente en estaciones de radio.

## Identidad independiente de main

- `main`: `com.victorflores.streambeatmusic` (StreamBeat Music en Android/iOS).
- `store`: conserva `com.victorflores.streambeat` en Android/iOS.

Los cambios de la antigua rama de trabajo `dev-main` están integrados en `main`.
Las nuevas ramas de trabajo de StreamBeat Music deben partir de `main`.

Android, iOS y macOS usan el nuevo identificador en todas las configuraciones;
Linux también tiene su propio application ID. En Android/iOS se pueden instalar
ambas apps a la vez y cada una mantiene sus datos locales. El enlace de retorno
es `com.victorflores.streambeatmusic://auth-callback`, también en el archivo de
ejemplo. No reutilizar un `monetization.local.json` que apunte al callback antiguo.
Al integrar cambios futuros entre ramas, conservar la identidad de la rama destino.

`flutter run` permite probar la app sin configurar cuentas ni compras. Para
separar también los datos remotos, usar un proyecto Supabase propio, aplicar las
migraciones/funciones de este repositorio y registrar el nuevo callback en Auth.
Usar las claves públicas de ese proyecto y aplicaciones/productos propios en
RevenueCat y las tiendas. Cambiar el ID del binario no crea estos servicios.
Android e iOS incluyen IDs de aplicación de prueba de AdMob; los IDs de producción
deben pertenecer a StreamBeat Music (ver `docs/MONETIZATION.md`). Para instalar en
un iPhone físico o distribuir, configurar la firma del nuevo bundle ID en Apple.
En web, usar un origen/puerto y configuración propios para aislar el almacenamiento.

## Requisitos

- Flutter SDK 3.8 o posterior
- Xcode con Swift Package Manager para iOS o macOS
- Android SDK para Android

## Ejecutar

    flutter pub get
    flutter run

Para habilitar cuenta, suscripción y anuncios usa el archivo de ejemplo en
`config/monetization.example.json`:

    cp config/monetization.example.json config/monetization.local.json
    flutter run --dart-define-from-file=config/monetization.local.json

La arquitectura, el esquema y el procedimiento de publicación están descritos
en `docs/MONETIZATION.md`.

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
