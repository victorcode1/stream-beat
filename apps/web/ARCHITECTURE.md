# Arquitectura de StreamBeat web

Sitio público Next.js App Router con React y TypeScript. Las rutas se prerenderizan; no hay API, autenticación, base de datos ni dependencias del runtime Flutter.

## Estructura

- `src/app`: páginas, layout, CSS global, robots y sitemap.
- `src/components`: marca, navegación, capturas, iconos, descarga y FAQ.
- `src/content/features.ts`: funciones verificadas y preguntas frecuentes.
- `src/lib/site.ts`: origen público y enlaces oficiales.
- `src/lib/metadata.ts`: metadatos por página.
- `public`: marca y capturas locales reales de la edición store.

La identidad visual usa azul petróleo `#0c242a`, verde turquesa `#0ed3bc`, blanco frío `#f5faf9`, gris `#536b70` y líneas `#cddedb`. La tipografía Geist se sirve localmente con su licencia. La portada se organiza como una señal que recorre el mundo, con órbitas estáticas alrededor de una captura real. Las secciones alternan fondo claro y azul petróleo, sin animaciones automáticas. El menú se ajusta a dos filas en móvil. FAQ usa details/summary nativos.

La fuente del contenido es local y no hay solicitudes al CMS. No se publican cifras, testimonios ni precios inventados. La descarga oficial es Android; iOS no se anuncia como disponible. Emisoras, privacidad y eliminación histórica conservan los destinos públicos existentes en GitHub Pages. El dominio de Vercel es independiente de esos servicios.

## Despliegue y validación

Vercel compila desde `apps/web`. `NEXT_PUBLIC_SITE_URL` configura canonical y sitemap; valor por defecto `https://streambeat-web.vercel.app`. No se necesitan secretos. `npm run build` usa Webpack para seguir el sitio de referencia. `npm run lint`, `npm run typecheck`, `npm run format:check` y `npm run build` comprueban el sitio. Verificar HTML público, enlaces internos, assets, robots y sitemap después de publicar. Las pruebas del sitio no certifican reproducción ni compras en la app Flutter.
