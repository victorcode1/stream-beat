# StreamBeat

Aplicación Flutter para descubrir música, reproducir audio y explorar estaciones de radio internacionales.

## Datos y privacidad

StreamBeat Music (`main`) es una app de uso interno: no tiene cuentas,
publicidad ni pagos integrados, y los datos de la app se guardan de forma local:

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

## Web de StreamBeat Music (`main`)

La aplicación web se publica en `https://streambeat-music.vercel.app`, separada
del sitio informativo de la edición de radio (`streambeat-web.vercel.app`).
Para publicar se compila Flutter localmente y se sube únicamente `build/web`:

    flutter build web --release
    cp deployment/vercel.json build/web/vercel.json
    vercel link --cwd build/web --project streambeat-music --scope victors-projects-9a3ff695 --yes
    vercel deploy --cwd build/web --prod --scope victors-projects-9a3ff695 --yes

La configuración conserva las rutas de la app al recargar y evita almacenar
versiones antiguas del código de inicio. Las donaciones abren
`https://ko-fi.com/streambeat` desde Ajustes. Ko-fi gestiona el pago externo;
no hay claves ni webhooks pendientes para este enlace.

En web la comprobación de conexión consulta `version.json` en el mismo origen,
con una URL nueva en cada revisión para evitar respuestas de la caché. Algunas
fuentes externas, como las tendencias de YouTube Music, pueden restringir las
consultas del navegador mediante CORS; publicar en Vercel no elimina esa restricción.

## Funcionalidades en main

- Búsqueda y reproducción de música
- Recomendaciones por país
- Radios internacionales y explorador de radio
- Reproducción en segundo plano
- Favoritos, playlists y ajustes locales
- Apoyo voluntario a StreamBeat Music desde Ajustes mediante [Ko-fi](https://ko-fi.com/streambeat). El enlace abre el navegador externo; no requiere claves API, SDK de pagos ni un servidor. Las donaciones no desbloquean funciones.

## Aviso sobre contenido de terceros

Las marcas, catálogos y emisiones pertenecen a sus respectivos titulares. Antes de publicar una versión en una tienda, confirma que cada fuente de audio y su forma de reproducción cumplen los términos de servicio y las licencias aplicables.
