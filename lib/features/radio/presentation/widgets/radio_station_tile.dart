import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/theme/custom_theme.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/radio/data/custom_station.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/presentation/widgets/station_links.dart';
import 'package:flow_music/shared/widgets/optimized_network_image.dart';
import 'package:flutter/material.dart';

/// Fila reutilizable para mostrar una emisora. Se usa en favoritos y en las
/// listas de radios. Mantiene el mismo lenguaje visual que las canciones.
class RadioStationTile extends StatelessWidget {
  const RadioStationTile({
    super.key,
    required this.station,
    required this.onTap,
    this.onAddToPlaylist,
    this.onRemove,
    this.removeLabel,
  });

  final RadioStation station;
  final VoidCallback onTap;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onRemove;
  final String? removeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final extras = theme.extension<FlowThemeExtras>();

    final artwork = station.artworkUrl;
    final borderRadius = BorderRadius.circular(20);

    return Material(
      color: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: extras?.subtleStroke ?? colors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox.square(
                  dimension: 58,
                  child: artwork.isEmpty
                      ? _Placeholder(colors: colors)
                      : OptimizedNetworkImage(
                          url: artwork,
                          displaySize: 58,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _Placeholder(colors: colors),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      station.name.isEmpty
                          ? LocaleKeys.radio.tr()
                          : station.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    if (station.country.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        station.country,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ...[
                PopupMenuButton<_StationAction>(
                  tooltip: LocaleKeys.menu.tr(),
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                  onSelected: (action) {
                    switch (action) {
                      case _StationAction.addToPlaylist:
                        onAddToPlaylist?.call();
                      case _StationAction.remove:
                        onRemove?.call();
                      case _StationAction.website:
                        handleStationLinkAction(context, station, 'website');
                      case _StationAction.report:
                        handleStationLinkAction(context, station, 'report');
                    }
                  },
                  itemBuilder: (context) => [
                    if (stationWebUri(station.homepage) != null)
                      PopupMenuItem(
                        value: _StationAction.website,
                        child: Text(LocaleKeys.station_website.tr()),
                      ),
                    PopupMenuItem(
                      value: _StationAction.report,
                      child: Text(LocaleKeys.station_report_removal.tr()),
                    ),
                    if (onAddToPlaylist != null)
                      PopupMenuItem(
                        value: _StationAction.addToPlaylist,
                        child: Row(
                          children: [
                            Icon(
                              Icons.playlist_add_rounded,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(LocaleKeys.add_to_radio_playlist.tr()),
                          ],
                        ),
                      ),
                    if (onRemove != null) ...[
                      if (onAddToPlaylist != null) const PopupMenuDivider(),
                      PopupMenuItem(
                        value: _StationAction.remove,
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: colors.error,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              removeLabel ?? LocaleKeys.delete.tr(),
                              style: TextStyle(color: colors.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 4),
              ],
              IconButton.filled(
                onPressed: onTap,
                icon: const Icon(Icons.play_arrow_rounded),
                tooltip: LocaleKeys.play.tr(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _StationAction { addToPlaylist, remove, website, report }

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.colors});
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.radio_rounded, color: colors.primary),
    );
  }
}
