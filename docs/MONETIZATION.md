# Monetización de StreamBeat

StreamBeat usa un modelo freemium deliberadamente discreto:

- La versión gratuita muestra como máximo un banner adaptativo de AdMob.
- El banner no cubre los controles y puede aparecer durante la reproducción.
- Aportes voluntarios de US$0.99, US$2.99 y US$4.99 (precio base estadounidense;
  la tienda muestra el precio y moneda de cada región).
- Productos no consumibles `streambeat_support_small`,
  `streambeat_support_medium` y `streambeat_support_large`. Cualquier importe
  activa `remove_ads`, sin renovación automática. No se venden mensualidad
  ni una opción llamada Premium de por vida.
- Los aportes no eliminan anuncios de las propias emisoras. Ninguna compra
  habilita almacenamiento o sincronización en la nube: la biblioteca es local.
- Cada producto se compra una vez y el beneficio puede restaurarse sin cuenta.
- Compras anteriores conservan sus derechos; no se desconectan los productos
  históricos del entitlement. Las mensualidades antiguas se reconocen solo
  para mantener/cancelar el acceso existente, sin ofertarlas de nuevo.
- No hay intersticiales, anuncios de apertura ni recompensados.

## Límites de arquitectura

La aplicación no tiene inicio de sesión ni conexión con Supabase. Los aportes y
la restauración funcionan mediante RevenueCat y la cuenta de Google Play o
App Store, sin una cuenta de StreamBeat. El SDK conserva su identidad local y
la información de compras; una instalación nueva utiliza una identidad anónima.
La app no llama a login/logout ni cambia la identidad del comprador.

Para reinstalación y restauración sin cuenta, verificar en RevenueCat que los
productos sean **no consumibles** y que el comportamiento de restauración sea
**Transfer to new App User ID**, como indica
[su documentación](https://www.revenuecat.com/docs/projects/restore-behavior).
El usuario puede pulsar «Restaurar compra» con la misma cuenta de la tienda.
RevenueCat verifica los derechos y mantiene su caché local; no se concede el
beneficio mediante un booleano local editable. La compra no se transfiere entre
Google Play y App Store automáticamente.

El nuevo cliente utiliza explícitamente el offering `support`. El offering
`default` no se altera para evitar afectar clientes publicados antes de esta
migración. Los tres productos deben estar conectados a `remove_ads` y al
nuevo offering antes de distribuir esta versión.

## Variables de compilación

Copiar `config/monetization.example.json` a
`config/monetization.local.json` y completar solo claves públicas. Compilar con:

    dart run tool/verify_monetization_config.dart
    flutter build appbundle --release \
      --dart-define-from-file=config/monetization.local.json

La configuración del cliente solo necesita los identificadores públicos de
RevenueCat y AdMob. No incluye claves Supabase, clientes OAuth ni callbacks de
autenticación. Las herramientas de validación ya no exigen esos valores.

## Backend retirado del cliente

La app no inicializa Supabase, no envía analítica a sus tablas y no utiliza
perfiles ni webhooks para otorgar el beneficio sin anuncios. Se retiraron los
SDK de Supabase, Google Sign-In y Sign in with Apple del cliente. Los archivos
históricos de `supabase/` se conservan como infraestructura anterior; este
cambio no borra usuarios, datos, funciones ni proyectos remotos.

## Datos de uso locales

Favoritos, playlists, preferencias e historial se guardan solo en el
dispositivo y funcionan sin red. No hay respaldo remoto, sincronización entre
dispositivos ni opción de compra que los habilite. Al actualizar se conserva la
biblioteca visible del dispositivo, incluidos favoritos, playlists y preferencias.
Se recuperan escrituras pendientes de la versión anterior y se conservan los
archivos locales históricos, sin autenticación ni cambios entre cuentas.
Configuración no muestra estado de nube, sincronización manual ni exportación
de copias remotas; permite exportar la biblioteca local como JSON mediante el
menú de compartir, tras advertir que las URLs de emisoras personalizadas pueden
incluir información privada.

## Infraestructura histórica de nube

Versiones anteriores ofrecían una copia en la nube a mensualidades históricas
mediante la función `cloud-sync-access`, la tabla `cloud_subscription_access`,
`cloud_library`, `user_data_sync` y una limpieza diaria de retención. Desde esta
versión la app no invoca esas funciones ni depende de esas tablas, y sus
migraciones no forman parte del flujo de esta versión. La prueba
`supabase/tests/paid_cloud_sync.sql` y la variable `REVENUECAT_CLOUD_API_KEY`
pertenecen a esa infraestructura. Esta versión no borra datos remotos guardados
antes ni retira esa infraestructura; hacerlo requiere un cambio de backend aparte.

## Tiendas y RevenueCat

1. Mantener el entitlement `remove_ads` en RevenueCat.
2. Crear los tres productos no consumibles `streambeat_support_small`,
   `streambeat_support_medium` y `streambeat_support_large`, con precios base
   estadounidenses de US$0.99, US$2.99 y US$4.99, respectivamente.
3. Asociar cada producto a `remove_ads` y a su package `small`, `medium` o
   `large` del offering `support` en la plataforma correspondiente.
4. Conservar los productos históricos y sus derechos para clientes anteriores.
5. Verificar la restauración entre identificadores anónimos y probar compra y
   restauración con usuarios sandbox, incluida una reinstalación.

El 2 de octubre de 2026 se activaron los tres aportes Android en las 174
regiones de facturación admitidas por Google Play, con precios locales e
impuestos calculados por la tienda. Se importaron en RevenueCat como no
consumibles y se vincularon a `remove_ads` y a `support`. La configuración del
catálogo no sustituye una prueba de compra real o sandbox en un dispositivo.

Google Play requiere que primero exista un AAB que incluya Play Billing. Apple
y Google deben mostrar y procesar el pago; una pasarela web directa no cumple
las reglas generales para quitar anuncios, que es una función digital.

## AdMob y privacidad

Los builds debug usan IDs de prueba oficiales. Android e iOS tienen configurados
los application IDs de StreamBeat en la cuenta activa de AdMob. UMP se consulta en
cada arranque, no se solicita un anuncio hasta que `canRequestAds` lo permite,
y Ajustes muestra la entrada de privacidad cuando sea obligatoria.

AdMob exige que `app-ads.txt` exista en la raíz del dominio publicado como sitio
del desarrollador. El archivo versionado está en `docs/app-ads.txt`, pero con el
sitio actual de GitHub Pages debe quedar accesible exactamente en
`https://victorcode1.github.io/app-ads.txt`; publicarlo solo bajo
`/flow-music/app-ads.txt` no completa la verificación.

El 3 de noviembre de 2026 se confirmó la cuenta original aprobada de StreamBeat,
asociada a `victorflores20511@gmail.com`, publicador `pub-7471220027528882`:

| Plataforma | App de AdMob                             | Banner principal                         |
| ---------- | ---------------------------------------- | ---------------------------------------- |
| Android    | `ca-app-pub-7471220027528882~6944234131` | `ca-app-pub-7471220027528882/1890579975` |
| iOS        | `ca-app-pub-7471220027528882~2622781522` | `ca-app-pub-7471220027528882/8996618184` |

Android está vinculado a `com.victorflores.streambeat` en Google Play y AdMob
muestra «Lista — Anuncios habilitados». iOS sigue pendiente de vincular su ficha
pública de App Store y muestra publicación limitada.

La cuenta `pub-6310779950033208`, usada temporalmente el 2 de noviembre, fue
rechazada por duplicidad. No se deben distribuir compilaciones con sus IDs.
Los identificadores nativos y `config/monetization.local.json` vuelven a usar
la cuenta original aprobada. El cierre de la cuenta duplicada no se ha realizado.

El archivo público `app-ads.txt` incluye el publicador original y conserva la
entrada adicional de la cuenta duplicada; esa entrada no obliga a usar sus IDs.
Editar la configuración local no modifica los binarios ya instalados.

En la cuenta original ya existe un mensaje europeo publicado para StreamBeat
(desde el 14 de agosto de 2026); la pantalla de privacidad también muestra un
mensaje activo para las reglamentaciones estatales de EE. UU. No se modificaron
esos mensajes durante esta corrección.

En la consulta del 3 de noviembre de 2026, el perfil de pagos de la cuenta
original mostraba USD 0.17 y un umbral mensual de USD 100.00. La página principal
indicaba que la verificación de identidad y los detalles bancarios todavía no
estaban disponibles hasta alcanzar el ingreso mínimo correspondiente. Estos
saldos y estados son una consulta puntual y deben comprobarse en AdMob antes
de tomar decisiones de cobro.

## Comprobaciones de la versión 1.1.17 (26)

Se retiró el acceso de StreamBeat y la dependencia de Supabase del cliente.
La migración conserva la biblioteca visible al actualizar y no borra datos
remotos históricos. Android conserva explícitamente el constructor de
`WorkDatabase_Impl` para evitar el cierre de WorkManager con R8 en producción.

Los aportes de importe libre externos son independientes y no deben activar el
entitlement `remove_ads`. El 3 de noviembre de 2026 se configuró
[Ko-fi de StreamBeat](https://ko-fi.com/streambeat), con PayPal conectado y Panamá
confirmado como país. El formulario usa dólares estadounidenses, importe libre
desde USD 1, sin importes sugeridos y con aporte único por defecto. La descripción
y el agradecimiento aclaran que el apoyo no quita anuncios ni desbloquea funciones.

Se comprobó la página pública sin iniciar sesión y se introdujo USD 2.50: el
botón reflejó el importe y la opción mensual permaneció desmarcada. No se realizó
un pago; la recepción efectiva de fondos todavía requiere una transacción real.
La compilación 26 conserva los tres aportes de las tiendas y la restauración,
sin enlace externo. La integración del enlace corresponde a la compilación 27.

En la prueba manual del 3 de noviembre de 2026 con un HONOR RKY-LX3 (Android 14),
la compilación release mostró los tres importes y «Restaurar compra», sin acceso
ni registro. La restauración devolvió un beneficio activo, cambió la tarjeta a
«StreamBeat sin anuncios» y retiró el banner sin pedir una cuenta de StreamBeat.
La prueba no generó una compra nueva. La configuración nativa de iOS pasó la
validación local; esta retirada de autenticación no se compiló ni se probó en iOS.

## Aporte externo en la versión 1.1.17 (27)

En Ajustes se añadió «Apoyar StreamBeat» con el botón «Aportar otro importe».
Abre `https://ko-fi.com/streambeat` en el navegador externo y aclara que el apoyo
es voluntario, desde USD 1, sin eliminar anuncios ni desbloquear funciones.
No inicia compras, no modifica RevenueCat y no otorga `remove_ads`. Los errores
de apertura se comunican mediante el aviso de enlace no disponible.

El botón se muestra en Android, web y escritorio no Apple, incluso para usuarios
que ya tienen el beneficio sin anuncios. Las compilaciones nativas de iOS y
macOS lo ocultan: no se ha implementado la verificación de storefront ni los
permisos regionales de Apple. No se usa el idioma o la ubicación del dispositivo
para inferir la tienda del comprador.

El 3 de noviembre de 2026 se desactivaron las mensualidades de Ko-fi y se retiró
la cuenta del modo Standard. Los aportes únicos tienen 0 % de comisión de Ko-fi;
las comisiones de procesamiento de PayPal siguen aplicándose. Se confirmó que
el mínimo de USD 1 y el formulario de importe libre permanecen guardados.

La decisión para Android se basa en la excepción de aportes directos sin acceso
a contenido o servicios digitales de la
[política de Google Play](https://support.google.com/googleplay/android-developer/answer/10281818?hl=en).
Se eliminó la comisión de plataforma de acuerdo con la
[documentación de Ko-fi](https://help.ko-fi.com/hc/en-us/articles/360002506494-Does-Ko-fi-take-a-fee).
Esta es una interpretación para implementar el flujo, no una aprobación de la
tienda. Las condiciones de Apple se documentan en las
[reglas 3.1.1 y 3.2.1](https://developer.apple.com/app-store/review/guidelines/).

Validación local: 196 pruebas correctas, una omitida por el proyecto y análisis
de `lib` y `test` sin avisos. Las pruebas de interfaz comprueban la apertura de
Ko-fi en modo externo sin compra de la tienda, los errores de apertura y la
ausencia del botón en iOS/macOS. No se ha efectuado una transacción real de Ko-fi
ni se ha publicado esta compilación en las tiendas.

Prueba en dispositivo del 3 de noviembre de 2026: la compilación release 1.1.17
(27) se instaló en el HONOR RKY-LX3. Con el beneficio sin anuncios activo,
Ajustes mostró «Apoyar StreamBeat» y «Aportar otro importe»; al pulsarlo se
abrió `ko-fi.com/streambeat` en el navegador externo con la página de StreamBeat
cargada y sin iniciar ninguna compra de la tienda. También se generó
`build/app/outputs/bundle/release/app-release.aab` (versionCode 27) para Google
Play; no se ha subido a Play Console.
