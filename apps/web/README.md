# StreamBeat web

Sitio público de la edición de radio de StreamBeat. Vive en el repositorio original, en `apps/web`, separado de la app Flutter.

## Desarrollo

Requiere Node.js 22 o posterior.

```sh
cd apps/web
npm ci
npm run dev
```

## Comprobaciones

```sh
npm run format:check
npm run lint
npm run typecheck
npm run build
```

## Publicación

Vercel: proyecto `streambeat-web`, directorio raíz `apps/web`, framework Next.js. Establece `NEXT_PUBLIC_SITE_URL` con el origen público antes de compilar si cambia el dominio. El valor predeterminado es `https://streambeat-web.vercel.app`.

Desde este directorio:

```sh
vercel deploy --prod
```

## Contenido y límites

- `/`: presentación, capturas reales, funciones, preguntas y descarga.
- `/funcionalidades`: funciones de la edición de radio.
- `/descargar`: Google Play y requisitos de uso.
- `/contacto`: soporte, titulares de emisoras y privacidad.
- SEO: canonical, Open Graph, Twitter, JSON-LD, sitemap y robots.
- `src/lib/site.ts` centraliza enlaces y origen. `src/content/features.ts` contiene funciones y preguntas.
- `public/screenshots` contiene las capturas de `store_assets/screenshots/android`. Los datos legales siguen publicados en sus direcciones existentes de GitHub Pages.
- No conecta Supabase, no ejecuta Flutter, no crea cuentas y no reproduce audio en el navegador. La web presenta la edición de radio; la rama musical `main` tiene otro alcance.
- Las afirmaciones de privacidad se basan en el README y política vigentes del checkout `store`: biblioteca local, sin sincronización y aportes opcionales para quitar anuncios. No se fijan precios ni se anuncia disponibilidad en iOS.
- `public/app-ads.txt` contiene el publisher aprobado. No se modifican las URLs de las políticas ni los servicios que usa la app.
