---
version: 1
slug: "lib-features-home"
primary_target: "lib/features/home"
related_targets: ["lib/features/song","lib/features/search","lib/features/library"]
---

## Alcance

Rediseño de StreamBeat Music (rama main, iOS por TestFlight): Inicio,
Reproductor, Búsqueda y resultados, y Biblioteca. Modo Operate: pantallas de
trabajo diario con controles nativos de iOS.

## Audiencia y tarea

El dueño y gente cercana. Abrir, retomar lo que sonaba o encontrar algo en
segundos, muchas veces con datos móviles. El Inicio abre con «Seguir
escuchando»; debajo, éxitos del país y sugerencias.

## Restricciones

- Nombre: StreamBeat Music. Todo lo demás es libre.
- Evitar: parecerse a Spotify, recargo visual, pantallas vacías esperando la
  red (siempre mostrar lo guardado en caché primero), letra pequeña u objetivos
  táctiles por debajo de 44 pt.

## Direction contract

THESIS: La música que suena se reconoce por capas, como una mola guna: lo
activo queda rodeado de contornos de color concéntricos. Rechaza la cuadrícula
gris de tarjetas con un verde de acento.

OWN-WORLD: Fondo casi negro cálido como tela de base. Telas de color en capas:
rojo mola, naranja maravilla y turquesa, con amarillo solo como acento puntual.
Un único tinte interactivo (rojo mola). Superficies como paños superpuestos con
canales finos entre capas; sin vidrio ni brillos.

STORY: Al abrir, ves lo que sonaba y lo retomas con un toque; luego descubres
los éxitos de tu país ordenados por tamaño, y tu biblioteca queda a una
pestaña.

FIRST VIEWPORT: Barra de pestañas nativa abajo. Título grande «Inicio».
Arriba, tarjeta «Seguir escuchando» de ancho completo con contornos
concéntricos y botón de reproducir de 56 pt. Debajo, fila horizontal de
recientes y la lista numerada «Éxitos en Panamá», donde el #1 es el más grande.

FORM: Candidato 7 de la lista propia, Mola. seed:3ca2536d1c2f3717

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Refuerzos tomados de las retadoras

- Cada canción lleva su placa fija: título, artista y una línea de dato.
- El tamaño codifica la importancia: el #1 de los éxitos es el más grande.
- Todas las carátulas comparten escala y línea base dentro de cada sección.
- Nada se rotula dos veces; las cifras de duración y posición son tabulares.

## Decisiones abiertas

- Endpoints de YouTube Music para éxitos por país y sugerencias: se conectan
  en esta construcción, con caché local para no mostrar pantallas vacías.
