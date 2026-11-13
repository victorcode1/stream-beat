import 'package:flow_music/core/theme/visual_style.dart';
import 'package:flow_music/features/history/data/playback_history_entry.dart';
import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/features/song/presentation/widgets/modern_player_hero.dart';
import 'package:flow_music/shared/widgets/style_contour.dart';
import 'package:flutter/material.dart';

/// Encabezado de seccion del Inicio. Cada estilo le pone su voz: Mola lo tiñe
/// con una tela y tres franjas, Carteles lo imprime en una banda de color y en
/// mayusculas, Clasico y Monocromo lo dejan en el color del texto.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    required this.index,
    this.trailing,
  });

  final String title;

  /// Posicion de la seccion en la pantalla; elige el color de su tela.
  final int index;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.styleTokens;
    final sectionColor = tokens.sectionColor(index);
    final text = tokens.uppercaseHeadings ? title.toUpperCase() : title;
    final baseStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: tokens.style == VisualStyle.carteles
          ? FontWeight.w400
          : FontWeight.w800,
      letterSpacing: tokens.style == VisualStyle.carteles ? 0.4 : -0.3,
    );

    final Widget heading;
    if (tokens.style == VisualStyle.carteles && sectionColor != null) {
      // Carteles: el titulo impreso sobre una banda de papel fluorescente.
      heading = DecoratedBox(
        decoration: BoxDecoration(color: sectionColor),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 12, 2),
          child: Text(
            text,
            style: baseStyle?.copyWith(color: const Color(0xFF0A0A0A)),
          ),
        ),
      );
    } else if (tokens.style == VisualStyle.mola && sectionColor != null) {
      // Mola: tres franjas cortas de tela delante del titulo teñido.
      heading = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MolaStripes(colors: tokens.contourColors, lead: sectionColor),
          const SizedBox(width: 10),
          Flexible(
            child: Text(text, style: baseStyle?.copyWith(color: sectionColor)),
          ),
        ],
      );
    } else {
      heading = Text(text, style: baseStyle);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Align(alignment: Alignment.centerLeft, child: heading),
        ),
        ?trailing,
      ],
    );
  }
}

class _MolaStripes extends StatelessWidget {
  const _MolaStripes({required this.colors, required this.lead});

  final List<Color> colors;
  final Color lead;

  @override
  Widget build(BuildContext context) {
    final stripes = [lead, ...colors.where((color) => color != lead)].take(3);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, color) in stripes.indexed)
          Container(
            width: 18 - index * 4,
            height: 3,
            margin: const EdgeInsets.symmetric(vertical: 1.5),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}

/// Caratula cuadrada con el radio del estilo y respaldo cuando falta imagen.
class HomeArtwork extends StatelessWidget {
  const HomeArtwork({
    super.key,
    required this.url,
    required this.size,
    this.icon = Icons.music_note_rounded,
  });

  final String url;
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = context.styleTokens.cardRadius.clamp(0.0, 16.0);
    final fallback = ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(child: Icon(icon, color: colors.primary)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: url.isEmpty
            ? fallback
            : PlayerArtworkImage(
                url: url,
                fallback: fallback,
                cacheWidth: (size * 3).round(),
              ),
      ),
    );
  }
}

/// Lo ultimo que sonaba, listo para retomarse con un toque. Es la primera
/// tarjeta del Inicio; en Mola lleva los contornos concentricos.
class ContinueListeningCard extends StatelessWidget {
  const ContinueListeningCard({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final PlaybackHistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tokens = context.styleTokens;
    final radius = tokens.cardRadius.clamp(0.0, 16.0);
    final isRadio = entry.kind == PlaybackHistoryKind.radio;

    final card = Material(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              HomeArtwork(
                url: entry.thumbnailUrl,
                size: 76,
                icon: isRadio ? Icons.radio_rounded : Icons.music_note_rounded,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (entry.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Objetivo de 56 pt: es la accion principal de la pantalla.
              SizedBox.square(
                dimension: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 32,
                    color: colors.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return StyleContour(radius: radius, child: card);
  }
}

/// Fila horizontal de caratulas: lo escuchado hace poco o «Para ti».
class HomeCoverRow<T> extends StatelessWidget {
  const HomeCoverRow({
    super.key,
    required this.items,
    required this.title,
    required this.subtitle,
    required this.artwork,
    required this.onTap,
    this.size = 132,
  });

  final List<T> items;
  final String Function(T item) title;
  final String Function(T item) subtitle;
  final String Function(T item) artwork;
  final ValueChanged<T> onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: size + 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = items[index];
          return SizedBox(
            width: size,
            child: InkWell(
              onTap: () => onTap(item),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HomeArtwork(url: artwork(item), size: size),
                  const SizedBox(height: 8),
                  Text(
                    title(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Exitos del pais numerados. El tamaño dice la importancia: el #1 ocupa una
/// fila grande; del #2 en adelante, filas compactas con cifras tabulares.
class HomeChartList extends StatelessWidget {
  const HomeChartList({
    super.key,
    required this.items,
    required this.onTap,
    this.maxItems = 10,
  });

  final List<YouTubeSearchSuggestion> items;
  final ValueChanged<YouTubeSearchSuggestion> onTap;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final shown = items.take(maxItems).toList(growable: false);
    if (shown.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        _ChartRow(
          rank: 1,
          item: shown.first,
          artworkSize: 96,
          onTap: () => onTap(shown.first),
        ),
        for (var i = 1; i < shown.length; i++)
          _ChartRow(
            rank: i + 1,
            item: shown[i],
            artworkSize: 52,
            onTap: () => onTap(shown[i]),
          ),
      ],
    );
  }
}

class _ChartRow extends StatelessWidget {
  const _ChartRow({
    required this.rank,
    required this.item,
    required this.artworkSize,
    required this.onTap,
  });

  final int rank;
  final YouTubeSearchSuggestion item;
  final double artworkSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isLead = rank == 1;
    final rankColor = isLead
        ? (context.styleTokens.sectionColor(1) ?? colors.primary)
        : colors.onSurfaceVariant;
    const tabular = [FontFeature.tabularFigures()];

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: isLead ? 10 : 6,
        ),
        child: Row(
          children: [
            SizedBox(
              width: isLead ? 40 : 30,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style:
                    (isLead
                            ? theme.textTheme.headlineMedium
                            : theme.textTheme.titleMedium)
                        ?.copyWith(
                          color: rankColor,
                          fontWeight: FontWeight.w800,
                          fontFeatures: tabular,
                        ),
              ),
            ),
            const SizedBox(width: 10),
            HomeArtwork(url: item.thumbnailUrl, size: artworkSize),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayText,
                    maxLines: isLead ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (isLead
                                ? theme.textTheme.titleLarge
                                : theme.textTheme.titleSmall)
                            ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    item.channelTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (item.duration != null) ...[
              const SizedBox(width: 8),
              Text(
                _formatDuration(item.duration!),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFeatures: tabular,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
