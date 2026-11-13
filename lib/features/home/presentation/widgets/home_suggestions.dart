import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/flow_mix/presentation/widgets/flow_mix_card.dart';
import 'package:flow_music/features/history/data/playback_history_entry.dart';
import 'package:flow_music/features/home/presentation/providers/home_suggestions_provider.dart';
import 'package:flow_music/features/history/presentation/controllers/playback_history_controller.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/domain/station_directory_mode.dart';
import 'package:flow_music/features/radio/presentation/utils/play_radio_station.dart';
import 'package:flow_music/features/radio/presentation/widgets/add_station_dialog.dart';
import 'package:flow_music/shared/widgets/optimized_network_image.dart';
import 'package:flow_music/shared/widgets/style_section_header.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Portada de StreamBeat: conserva el diseño de descubrimiento, pero todas las
/// tarjetas reproducen emisoras de radio, no canciones ni vídeos.
class HomeSuggestions extends ConsumerWidget {
  const HomeSuggestions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (stationDirectoryIsSearchFirst) return const _PlayerHome();
    final suggestions = ref.watch(homeSuggestionsProvider);
    return suggestions.when(
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (_, _) => _HomeMessage(
        icon: Icons.wifi_off_rounded,
        title: LocaleKeys.home_stations_load_error_title.tr(),
        subtitle: LocaleKeys.home_stations_load_error_subtitle.tr(),
        actionLabel: LocaleKeys.retry.tr(),
        onAction: () => ref.invalidate(homeSuggestionsProvider),
      ),
      data: (data) {
        if (data.stations.isEmpty) {
          return _HomeMessage(
            icon: Icons.radio_outlined,
            title: LocaleKeys.home_no_stations_title.tr(),
            subtitle: LocaleKeys.home_no_stations_subtitle.tr(),
            actionLabel: LocaleKeys.radio.tr(),
            onAction: () => context.go('/radio'),
          );
        }
        return _DiscoverContent(
          stations: data.stations,
          countryName: data.countryName,
          countryCode: data.countryCode,
          usesFallback: data.usesFallback,
          onRefresh: () => ref.invalidate(homeSuggestionsProvider),
        );
      },
    );
  }
}

class _DiscoverContent extends ConsumerWidget {
  const _DiscoverContent({
    required this.stations,
    required this.countryName,
    required this.countryCode,
    required this.usesFallback,
    required this.onRefresh,
  });

  final List<RadioStation> stations;
  final String? countryName;
  final String? countryCode;
  final bool usesFallback;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hour = DateTime.now().hour;
    final playbackHistory = ref.watch(playbackHistoryControllerProvider);
    final greeting = hour < 12
        ? LocaleKeys.greeting_morning.tr()
        : hour < 19
        ? LocaleKeys.greeting_afternoon.tr()
        : LocaleKeys.greeting_evening.tr();
    final featured = stations.first;
    final stationsById = {
      for (final station in stations) _stationId(station): station,
    };
    final recent = _recentStations(playbackHistory, stationsById);
    final more = stations.skip(1).take(6).toList(growable: false);

    void play(RadioStation station, List<RadioStation> queue) {
      playRadioStation(
        context: context,
        ref: ref,
        station: station,
        queue: queue,
        index: queue.indexOf(station),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          Text(
            greeting,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            LocaleKeys.discover.tr(),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: countryName == null
                      ? LocaleKeys.category_for_you.tr()
                      : LocaleKeys.suggestions_for_country.tr(
                          args: [countryName!],
                        ),
                  selected: true,
                  onTap: onRefresh,
                ),
                const SizedBox(width: 10),
                _FilterChip(
                  label: LocaleKeys.popular_radio.tr(),
                  onTap: () => context.go('/radio'),
                ),
                const SizedBox(width: 10),
                _FilterChip(
                  label: LocaleKeys.radio_map_explorer.tr(),
                  onTap: () => context.go('/radio-map'),
                ),
              ],
            ),
          ),
          if (usesFallback) ...[
            const SizedBox(height: 12),
            Text(
              LocaleKeys.popular_stations_fallback.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 22),
          FlowMixCard(countryCode: countryCode ?? ''),
          const SizedBox(height: 28),
          if (recent.isNotEmpty) ...[
            StyleSectionHeader(
              title: LocaleKeys.recently_played.tr(),
              index: 0,
              trailing: TextButton(
                onPressed: () => context.go('/radio'),
                child: Text(LocaleKeys.see_all.tr()),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recent.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _RecentStationCard(
                  station: recent[index],
                  onTap: () => play(recent[index], recent),
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],
          _FeaturedStationCard(
            station: featured,
            onTap: () => play(featured, stations),
          ),
          if (more.isNotEmpty) ...[
            const SizedBox(height: 22),
            StyleSectionHeader(
              title: LocaleKeys.more_stations_for_you.tr(),
              index: 1,
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.88,
              ),
              itemCount: more.length,
              itemBuilder: (context, index) => _StationGridCard(
                station: more[index],
                onTap: () => play(more[index], stations),
              ),
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.go('/favorites'),
            icon: const Icon(Icons.favorite_border_rounded),
            label: Text(LocaleKeys.view_my_favorite_stations.tr()),
          ),
        ],
      ),
    );
  }

  String _stationId(RadioStation station) =>
      station.stationUuid.isEmpty ? station.streamUrl : station.stationUuid;
}

List<RadioStation> _recentStations(
  List<PlaybackHistoryEntry> history, [
  Map<String, RadioStation> stationsById = const {},
]) {
  return history
      .map((entry) {
        if (entry.stationData.isNotEmpty) {
          try {
            final station = RadioStation.fromJson(entry.stationData);
            if (station.isPlayable) return station;
          } catch (_) {
            // A malformed legacy history item should not break Home.
          }
        }
        return stationsById[entry.id];
      })
      .whereType<RadioStation>()
      .take(4)
      .toList(growable: false);
}

/// Portada de iOS y macOS: un reproductor sin catálogo propio. Invita a
/// buscar en el directorio público o a agregar un stream, y muestra lo que el
/// usuario ya escuchó.
class _PlayerHome extends ConsumerWidget {
  const _PlayerHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final recent = _recentStations(
      ref.watch(playbackHistoryControllerProvider),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        Text(
          LocaleKeys.player_home_title.tr(),
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          LocaleKeys.player_home_intro.tr(),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => context.go('/radio'),
          icon: const Icon(Icons.search_rounded),
          label: Text(LocaleKeys.station_search_directory.tr()),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => showAddStationDialog(context, ref),
          icon: const Icon(Icons.add_link_rounded),
          label: Text(LocaleKeys.station_add_by_url.tr()),
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 28),
          StyleSectionHeader(title: LocaleKeys.recently_played.tr(), index: 0),
          const SizedBox(height: 10),
          for (final station in recent) ...[
            _RecentStationCard(
              station: station,
              onTap: () => playRadioStation(
                context: context,
                ref: ref,
                station: station,
                queue: recent,
                index: recent.indexOf(station),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => context.go('/favorites'),
          icon: const Icon(Icons.favorite_border_rounded),
          label: Text(LocaleKeys.view_my_favorite_stations.tr()),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    this.selected = false,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primary : colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: selected ? colors.onPrimary : colors.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentStationCard extends StatelessWidget {
  const _RecentStationCard({required this.station, required this.onTap});

  final RadioStation station;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 250,
      child: Material(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _StationArt(station: station, size: 58),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        station.country.isEmpty
                            ? 'Radio en directo'
                            : station.country,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedStationCard extends StatelessWidget {
  const _FeaturedStationCard({required this.station, required this.onTap});

  final RadioStation station;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1.45,
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _StationArt(station: station, size: null),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.86),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'EN VIVO',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.onPrimary,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      station.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      station.country.isEmpty
                          ? 'Radio en directo'
                          : station.country,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: const Alignment(0.82, 0.72),
                child: IconButton.filled(
                  iconSize: 34,
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(18),
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                  ),
                  onPressed: onTap,
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StationGridCard extends StatelessWidget {
  const _StationGridCard({required this.station, required this.onTap});

  final RadioStation station;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: _StationArt(station: station, size: null),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                station.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                station.country.isEmpty ? 'Radio' : station.country,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StationArt extends StatelessWidget {
  const _StationArt({required this.station, required this.size});

  final RadioStation station;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: colors.primary.withValues(alpha: 0.16),
      child: Icon(
        Icons.radio_rounded,
        color: colors.primary,
        size: size == null ? 52 : 28,
      ),
    );
    final image = station.artworkUrl.isEmpty
        ? placeholder
        : OptimizedNetworkImage(
            url: station.artworkUrl,
            displaySize: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => placeholder,
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(size == null ? 18 : 14),
      child: size == null
          ? image
          : SizedBox.square(dimension: size!, child: image),
    );
  }
}

class _HomeMessage extends StatelessWidget {
  const _HomeMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: colors.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
