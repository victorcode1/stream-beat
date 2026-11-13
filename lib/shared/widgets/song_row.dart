import 'package:flow_music/features/home/presentation/widgets/home_mobile_sections.dart';
import 'package:flow_music/shared/widgets/playing_bars_indicator.dart';
import 'package:flutter/material.dart';

/// Fila de cancion para listas (resultados, biblioteca): caratula con el radio
/// del estilo, titulo, artista y duracion con cifras tabulares. La que suena
/// cambia la duracion por las barras animadas y su titulo toma el acento.
class SongRow extends StatelessWidget {
  const SongRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.artworkUrl,
    required this.onTap,
    this.duration,
    this.isCurrent = false,
    this.isPlaying = false,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
  });

  final String title;
  final String subtitle;
  final String artworkUrl;
  final VoidCallback onTap;
  final Duration? duration;

  /// Es la cancion activa del reproductor.
  final bool isCurrent;

  /// La cancion activa esta sonando (las barras se mueven).
  final bool isPlaying;

  /// Accion extra al final de la fila (menu, descargar...).
  final Widget? trailing;

  /// Margen interior; las listas con margen propio lo reducen.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    const tabular = [FontFeature.tabularFigures()];

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            HomeArtwork(url: artworkUrl, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isCurrent ? colors.primary : null,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isCurrent)
              PlayingBarsIndicator(
                isPlaying: isPlaying,
                color: colors.primary,
                size: 18,
              )
            else if (duration != null)
              Text(
                _formatDuration(duration!),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFeatures: tabular,
                ),
              ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
    }
    return '$minutes:$seconds';
  }
}
