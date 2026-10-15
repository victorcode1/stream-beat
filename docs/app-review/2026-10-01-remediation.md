# App Review: candidato de corrección del 1 de octubre de 2026

## Alcance y estado

App Store Connect: 6811965825. Bundle iOS: com.victorflores.streambeat.
Apple rechazó 1.1.15 (22) el 1 de octubre por 5.1.1(v) y 5.2.3.
La corrección está en un worktree aislado basado en `store`, revisión
30424617a5896a41777475d7b0b3277cc46e671d. No se modifica `main`.

## Historial del candidato 23 (sustituido; no subir)

- Compra mensual y vitalicia directamente desde Configuración, sin cuenta.
- Restauración accesible sin cuenta, incluso sin precios cargados.
- La disponibilidad de Supabase Auth no bloquea compras de la tienda.
- Los derechos Premium de RevenueCat activan la experiencia sin anuncios
  también para la identidad anónima; vencimiento mensual sigue aplicándose.
- Registro e inicio de sesión son opcionales. Solo la biblioteca en la nube
  requiere cuenta y suscripción mensual vigente verificada en el servidor.
- Textos de cuenta corregidos en español, inglés y portugués brasileño;
  política de privacidad local actualizada en español e inglés.

RevenueCat admite identidad anónima y asociación mediante `logIn`:
https://www.revenuecat.com/docs/customers/identifying-customers
La restauración con cuenta opcional necesita revisar `Transfer to new App User ID`:
https://www.revenuecat.com/docs/projects/restore-behavior
La política remota se verificó después: `Transfer to new App User ID`,
también en sandbox. No fue necesario modificarla.

## Evidencia local del candidato anterior

- Monetización y traducciones: 60 pruebas aprobadas.
- Cuenta, biblioteca, promoción y configuración: 33 pruebas aprobadas.
- Análisis de módulo y pruebas de monetización: sin incidencias.
- `dart run tool/verify_monetization_config.dart --platform=ios`: correcto.
- Compilación debug iOS, arranque y recarga en caliente: correctos.
- En el simulador, la compra mensual abrió el login de Apple sin abrir el
  formulario de registro de StreamBeat. Se canceló sin introducir credenciales
  ni efectuar el pago. Esto no prueba una transacción sandbox completa.
- Archivo iOS y exportación IPA de distribución: 1.1.15 (23), correctos.
  Bundle y versión verificados también dentro del IPA. No se ha subido a Apple.
- Estos checks no prueban transacciones reales de Apple ni la política remota.

## Comprobaciones pendientes (adaptadas al candidato 24)

1. Probar los tres aportes como invitado con Apple sandbox.
2. Comprobar que los anuncios desaparezcan y Premium persista tras reiniciar.
3. Probar restauración sin cuenta después de reinstalación, en otro dispositivo
   con la misma cuenta de la tienda y tras cerrar sesión en la app.
4. Probar vincular una compra de invitado al iniciar sesión opcionalmente,
   restaurar con una cuenta existente y cambiar de cuenta sin cruzar biblioteca.
5. La política remota de RevenueCat ya está verificada; falta validar su
   resultado con transacciones sandbox reales.
6. Revisar y firmar personalmente el PDF de relación desarrollador-app.
7. Adjuntar permisos reales de contenido o pedir aclaración a Apple antes de
   presentar 5.2.3 como resuelto. La documentación de Radio Browser sobre su
   directorio no acredita derechos sobre las emisiones subyacentes.
8. Subir/seleccionar el build corregido solo después de verificar el candidato,
   la política de privacidad ya está publicada tras el push autorizado,
   y reenviar con documentación suficiente. No afirmar aprobación ni publicación.

## Borrador inicial de respuesta (reemplazado por aclaración enviada)

Hello App Review,

Thank you for the October 1 review of StreamBeat 1.1.15 (22).

For guideline 5.1.1(v), we have corrected the purchase flow in our candidate:
users can purchase monthly or lifetime Premium and restore purchases without
registering or signing in. Store entitlements enable the ad-free experience
for guests. Registration is optional and used for account-specific cloud
library backup and synchronization. We will submit the corrected build after
sandbox validation.

For the requested relationship documentation, StreamBeat is the application
developed and maintained by Victor Flores, the developer account holder.
We have prepared a developer statement and supporting project evidence. We
will attach the personally reviewed and signed document.

Regarding third-party content under guideline 5.2.3, our prior technical
attachment describes directory-based discovery and direct playback. We
understand this is separate from documentary permissions for the broadcasts.
Could you clarify the additional documentary evidence you require for the
catalog/discovery service and for the individual radio streams? We are not
claiming that public stream URLs establish broadcaster authorization.

Thank you.

## Documentación de autoría

`output/pdf/StreamBeat-Developer-Relationship-DRAFT.pdf`: dos páginas,
declaración propuesta con firma vacía y apéndice de evidencia local.
No se ha firmado en nombre de Victor ni enviado a Apple. Los commits y bundle
apoyan la atribución; Apple puede requerir documentación adicional.

## Acciones del 1 de octubre, 10:54 AM (Panamá)

- Se envió una aclaración en App Store Connect. La conversación muestra
  `Messages (6)` y `Victor Flores — Today 10:54 AM`.
- Se informó que el build 23 permite compras/restauración sin cuenta y que
  la validación sandbox y la subida aún están pendientes.
- Se incluyeron los enlaces oficiales de Radio Browser (sitio, API y clientes)
  y se pidió distinguir entre documentación del directorio/API, emisiones
  concretas y relación desarrollador-app, indicando estaciones si aplica.
- No se afirmó que otras apps ni la licencia del catálogo acrediten derechos
  sobre las emisiones. Se pidió precisar el documento de autoría requerido.
- El intento de subida mediante `xcodebuild -exportArchive` falló con
  `Failed to Use Accounts`: Xcode requiere renovar la sesión Apple con acceso
  al equipo MTL4YJMX73. No se completó la subida ni el reenvío a revisión.
- El PDF permanece sin firma. No se ha sustituido la firma personal.

## Cambio de modelo solicitado después de la aclaración

El usuario sustituyó la propuesta anterior: no se subirá el build 23 ni se
ofrecerá suscripción mensual o Premium de por vida en el nuevo cliente.
El build 24 ofrece aportes voluntarios de US$0.99, US$2.99 y US$4.99.
Confirmó que aportar una vez quita la publicidad. Se usan tres productos
no consumibles, restaurables sin cuenta, vinculados a `remove_ads`.
La nube no forma parte del aporte. Se mantienen los derechos históricos
y las funciones de cancelación/portabilidad, sin vender planes antiguos.

La respuesta enviada a Apple a las 10:54 describe el candidato anterior.
Debe actualizarse al completar el nuevo build y catálogo; no equivale a
subida ni a reenvío del build 24.

## Evidencia del candidato 24 y catálogo configurado

- Código subido a `store`: commit b8ec452d5bc6288ab142aec046ccd27818563c82.
  GitHub Pages terminó de publicar la política ES/EN de aportes sin renovación.
- Build firmado 1.1.15 (24), IPA generado correctamente y bundle/versión
  verificados dentro del archivo. Subida completada con `Uploaded Runner` y
  `EXPORT SUCCEEDED` el 1 de octubre; Apple confirmó
  carga registrada a las 12:45 PM; posteriormente terminó de procesar y
  aparece como `Ready to Submit`. Build 24 seleccionado y guardado para 1.1.15.
  Registro local: `/private/tmp/streambeat-upload24.log`. Avisos dSYM de
  frameworks no bloquearon la carga.
- 75 pruebas de monetización, traducciones y configuración aprobadas;
  análisis de los archivos afectados sin incidencias.
- El simulador mostró los tres precios reales de Apple: US$0.99, US$2.99 y
  US$4.99. Comprar como invitado abrió el acceso de Apple, sin registro de
  StreamBeat. No se completó ni cobró una transacción.
- Captura nativa de 1320x2868 guardada en
  `store_assets/screenshots/ios/es-MX/iap-review-contributions-6.9.png`.
  La captura pública existente de Configuración no muestra ofertas antiguas.

### App Store Connect

Los tres productos son no consumibles y están en el mismo borrador iOS,
creado el 1 de octubre a las 12:28 PM por Victor Flores:

| Aporte | Product ID | Apple ID | Precio base EE. UU. |
| --- | --- | --- | --- |
| Pequeño | streambeat_support_small | 6818231576 | US$0.99 |
| Mediano | streambeat_support_medium | 6818244649 | US$2.99 |
| Grande | streambeat_support_large | 6818246866 | US$4.99 |

Los tres tienen disponibilidad en 175 territorios y futuros territorios,
localizaciones ES-MX/EN-US/PT-BR, notas y captura de revisión guardadas.
Estado: `Ready for Review`. El borrador se completó con la versión iOS 1.1.15 (24): contiene cuatro
artículos (versión y tres aportes). `Submit for Review` está habilitado, sin pulsar.
No equivale a envío, aprobación ni publicación.

La mensualidad, el producto vitalicio y el grupo antiguo se retiraron de la
presentación rechazada. Mensualidad y vitalicio se retiraron de venta;
los productos y derechos históricos permanecen para restauración y soporte.
La presentación histórica se actualizó primero con `Update Review`. Después
se retiró su último artículo mediante `Remove From Submission` para reunirlo
con las compras nuevas: Apple no admite agregar artículos nuevos a una
presentación con incidencias. La presentación anterior ahora muestra `Removed`,
y conserva su historial y siete mensajes. Build y metadatos no se borraron.
La versión se agregó al borrador existente de las 12:28 PM; Apple muestra
`Items Ready to Submit (4)`, `1.1.15 (24)` y `In-App Purchases (3)`.
Última actualización verificada: Victor Flores, 12:56 PM. Sin envío aún.

Descripción y texto promocional guardados en los tres idiomas; notas de
App Review actualizadas para el candidato 24, compra/restauración sin cuenta,
beneficio sin renovación, sin nube ni eliminación de anuncios de las emisoras.
La ficha Android se incluyó como evidencia de relación desarrollador-app:
https://play.google.com/store/apps/details?id=com.victorflores.streambeat
No se presenta como autorización sobre emisiones.

### RevenueCat

Offering `support` (ofrngdebb220961) configurado con packages personalizados
`small`, `medium` y `large`. Los tres productos iOS anteriores están asociados
al entitlement `remove_ads`. Política verificada: `Transfer to new App User ID`,
también en sandbox. Las credenciales IAP existentes son válidas.
Se conserva el offering anterior para clientes Android publicados y derechos
históricos. No se ha publicado una nueva versión Android ni creado su catálogo
nuevo de aportes en Google Play.

### Pendientes reales

- Build 24 subido, procesado, seleccionado y artículo de revisión actualizado.
  Los cuatro artículos están unidos en el borrador; falta validar sandbox y
  realizar el envío final de revisión con la documentación suficiente.
- Completar compra y restauración en Apple sandbox, reinicio/reinstalación
  y asociación opcional de cuenta; la pantalla de acceso no prueba estos flujos.
- La respuesta histórica de las 10:54 AM se actualizó con un nuevo mensaje
  enviado a las 12:47 PM: `Messages (7)`, build 24 subido y en procesamiento,
  tres aportes, sandbox pendiente y enlace de Google Play como autoría.
  Sigue pendiente la respuesta de Apple sobre documentación específica.
- Aclaración o documentación de emisoras para 5.2.3; Radio Browser y Google
  Play no sustituyen permisos. PDF de relación desarrollador-app pendiente
  de revisión y firma personal de Victor, sin enviar ni firmar por el agente.

La captura y el registro del catálogo se subieron a `store` en 88a6574.


### TestFlight preparado el 1 de octubre

- Cuenta existente de Victor agregada al grupo interno `StreamBeat Internal`.
  App Store Connect muestra `Invited`, 1 tester y 5 builds.
- Build `1.1.15 (24)` verificado como `Ready to Test` en ese grupo.
- Para la prueba básica, TestFlight utiliza sandbox automáticamente; no se creó
  otra cuenta ni se cambiaron credenciales o permisos de administración.
- La instalación en el iPhone y las transacciones siguen pendientes. El control
  remoto de Duplicación del iPhone falló al abrir TestFlight; no hay evidencia
  de compra completada ni de restauración en el dispositivo.
- Aceptar la invitación de Apple e instalar el build 24 desde TestFlight permite
  continuar esa validación. El envío final de App Review sigue sin realizarse.

## Continuación del 12 de octubre de 2026

- Estado inicial de Apple: 1.1.15 (24), `Ready for Review`, borrador de cuatro
  artículos sin enviar. Presentación anterior del 28 de septiembre: `Removed`.
- Se verificaron los tres aportes no consumibles, con localizaciones es-MX,
  en-US y pt-BR, captura/notas de revisión y disponibilidad internacional.
  La versión, descripción y texto promocional describen aportes sin renovación
  y compra/restauración sin cuenta; los planes antiguos están fuera del envío.
- Se revisaron el código de compras de invitado, almacenamiento local, capturas
  de iPhone/iPad y política de privacidad publicada del 2 de octubre.
- 93 pruebas enfocadas aprobadas; análisis de los módulos revisados sin
  incidencias; verificador de monetización iOS correcto.
- Se compiló el código actual de `store` (43ca6f0) para iOS como 1.1.15 (26),
  preservando 1.1.16+25 de `pubspec.yaml`, usado en Android. Archivo e IPA
  exportados; bundle, versión y build comprobados. Firma verificada con acceso
  al llavero. La IPA exportada incluye `beta-reports-active=true` y
  `get-task-allow=false`.
- La primera subida falló por falta de sesión Apple en Xcode 27. Tras iniciar
  sesión, la subida terminó con `Uploaded Runner` y `EXPORT SUCCEEDED`.
  Advertencias dSYM de GoogleMobileAds, Sentry y UserMessagingPlatform no
  impidieron la carga.
- Apple procesó el build 26; se seleccionó y guardó para 1.1.15. La versión
  se reunió con los tres aportes en el borrador original: cuatro artículos.
- Dossier actualizado de autoría, aportes y arquitectura guardado en
  `output/pdf/StreamBeat-App-Review-Dossier-2026-10-12.pdf`, revisado visualmente
  y adjuntado a la versión. Es un reporte técnico sin firma; no acredita
  permisos de emisoras. Se conservó la solicitud de aclaración sobre 5.2.3.
- Se corrigieron la descripción beta es-MX y las notas de TestFlight que
  todavía indicaban productos mensuales/vitalicios.
- Las credenciales proporcionadas se usaron para Xcode y se actualizaron en
  Contraseñas de macOS, en la entrada Apple existente y no compartida. No se
  guardan credenciales en este documento, en archivos del proyecto ni en memoria.
- El iPhone tenía una versión de desarrollo 1.1.7 (10). TestFlight falló al
  reemplazarla. Con autorización específica del usuario se respaldaron diez
  archivos de Documents en `/private/tmp/streambeat-library-before-testflight26`,
  se verificaron tamaños, y se eliminó solo `com.victorflores.streambeat`.
  La instalación limpia de TestFlight 1.1.15 (26) funcionó.
- Se verificaron arranque, rechazo de seguimiento/ubicación y pantalla de
  aportes como invitado con los tres precios reales. El aporte pequeño abrió
  el diálogo de Apple, que confirmó que la compra beta no cobra dinero. La
  compra terminó con el mensaje de éxito y el beneficio sin anuncios, sin
  cuenta de StreamBeat. El beneficio permaneció tras terminar y relanzar la app.
  La restauración se ejecutó como invitado; el usuario confirmó el toast de
  compra restaurada. Duplicación no capturó ese aviso breve: la confirmación
  de restauración es reportada por el operador del dispositivo.
- El dossier incorpora una tercera página con esta validación que reemplaza
  el estado pendiente anterior. Las notas de revisión distinguen compra
  observada, persistencia observada y restauración confirmada por el usuario.
- Envío final realizado el 12 de octubre a las 10:39 AM de Panamá. Apple
  confirmó `4 Items Submitted`: versión 1.1.15 (26) y tres aportes. Todos
  aparecen en `Waiting for Review`. Submission ID:
  `fc697da8-47b1-4395-b667-897631a7b4d9`. Aprobación/publicación pendientes.
  Captura: `tmp/app-review-submitted-build26.png`.
- La consulta de derechos 5.2.3 sigue abierta: se adjuntó evidencia de autoría
  y arquitectura, sin afirmar permisos de emisoras no proporcionados.
