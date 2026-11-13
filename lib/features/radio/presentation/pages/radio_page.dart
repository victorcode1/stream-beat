import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/audio/background_audio_handler.dart';
import 'package:flow_music/core/theme/custom_theme.dart';
import 'package:flow_music/core/utils/adaptive_layout.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/history/presentation/controllers/playback_history_controller.dart';
import 'package:flow_music/features/home/presentation/providers/text_search.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/data/models/radio_tag.dart';
import 'package:flow_music/features/radio/data/repositories/radio_browser_repository.dart';
import 'package:flow_music/features/radio/presentation/controllers/radio_favorites_controller.dart';
import 'package:flow_music/features/radio/presentation/controllers/radio_queue_controller.dart';
import 'package:flow_music/features/radio/presentation/widgets/radio_playlist_actions.dart';
import 'package:flow_music/features/radio/presentation/widgets/radio_station_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final RegExp _countryCodePattern = RegExp(r'^[A-Z]{2}$');

String _countryFlagEmoji(String countryCode) {
  final normalized = countryCode.trim().toUpperCase();
  if (!_countryCodePattern.hasMatch(normalized)) return '';

  const regionalIndicatorA = 0x1F1E6;
  const asciiA = 0x41;
  return String.fromCharCodes([
    regionalIndicatorA + normalized.codeUnitAt(0) - asciiA,
    regionalIndicatorA + normalized.codeUnitAt(1) - asciiA,
  ]);
}

class _FlagEmoji extends StatelessWidget {
  const _FlagEmoji({required this.flag, this.size = 18, this.dimension = 22});

  final String flag;
  final double size;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: dimension,
      child: Center(
        child: Text(
          flag,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: size, height: 1),
        ),
      ),
    );
  }
}

class RadioPage extends ConsumerStatefulWidget {
  const RadioPage({super.key});

  @override
  ConsumerState<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends ConsumerState<RadioPage> {
  final RadioBrowserRepository _repository = RadioBrowserRepository();
  late final TextEditingController _searchController;

  late Future<List<RadioStation>> _stationsFuture;
  late Future<List<RadioTag>> _tagsFuture;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  Timer? _debounce;
  String _selectedTag = '';
  String _selectedCountryCode = '';
  String? _playingStationUuid;
  PlayerState _playerState = PlayerState.stopped;
  bool _isLoadingPlayback = false;
  String _lastSearchText = '';

  static const _countryFilters = <String, String>{
    'US': 'US',
    'DO': 'RD',
    'MX': 'MX',
    'CO': 'CO',
    'PA': 'PA',
    'ES': 'ES',
    'AR': 'AR',
    'CL': 'CL',
    'VE': 'VE',
    'PE': 'PE',
    'EC': 'EC',
    'GT': 'GT',
    'CU': 'CU',
    'BO': 'BO',
    'PY': 'PY',
  };

  @override
  void initState() {
    super.initState();
    _tagsFuture = _repository.topTags();
    _playerState = flowAudioHandler.player.state;
    _playerStateSubscription = flowAudioHandler.player.onPlayerStateChanged
        .listen((state) {
          if (mounted) {
            setState(() => _playerState = state);
          }
        });

    _searchController = ref.read(searchProvider);
    _lastSearchText = _searchController.text;
    _searchController.addListener(_onSearchChanged);

    if (_lastSearchText.isEmpty) {
      _stationsFuture = _repository.topStations();
    } else {
      _stationsFuture = _repository.searchStations(name: _lastSearchText);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _playerStateSubscription?.cancel();
    _searchController.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    final text = _searchController.text;
    if (text == _lastSearchText) return;
    _lastSearchText = text;
    if (mounted) setState(() {});
    _scheduleSearch(text);
  }

  void _scheduleSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _loadStations(query: value);
    });
  }

  void _loadStations({String? query, String? tag, String? countryCode}) {
    final nextTag = tag ?? _selectedTag;
    final nextCountryCode = countryCode ?? _selectedCountryCode;
    final nextQuery = query ?? _searchController.text;

    setState(() {
      _selectedTag = nextTag;
      _selectedCountryCode = nextCountryCode;
      _stationsFuture =
          (nextQuery.isEmpty && nextTag.isEmpty && nextCountryCode.isEmpty)
          ? _repository.topStations()
          : _repository.searchStations(
              name: nextQuery,
              tag: nextTag,
              countryCode: nextCountryCode,
            );
    });
  }

  void _clearFilters() {
    _lastSearchText = '';
    _searchController.clear();
    setState(() {
      _selectedTag = '';
      _selectedCountryCode = '';
      _stationsFuture = _repository.topStations();
    });
  }

  Future<void> _toggleStation(RadioStation station) async {
    final isCurrentStation = station.stationUuid == _playingStationUuid;
    if (isCurrentStation && _playerState == PlayerState.playing) {
      await flowAudioHandler.pause();
      return;
    }

    if (isCurrentStation && _playerState == PlayerState.paused) {
      await flowAudioHandler.play();
      return;
    }

    await _playStation(station);
  }

  Future<void> _playStation(RadioStation station) async {
    if (!station.isPlayable || _isLoadingPlayback) return;

    setState(() {
      _isLoadingPlayback = true;
      _playingStationUuid = station.stationUuid;
    });

    try {
      final streamUrl = await _repository.countClickAndResolveUrl(station);
      final artUrl = await _repository.resolveArtworkUrl(station);
      await flowAudioHandler.playUrl(
        url: streamUrl,
        id: station.stationUuid.isEmpty ? streamUrl : station.stationUuid,
        title: station.name,
        artist: [
          if (station.country.isNotEmpty) station.country,
          if (station.codec.isNotEmpty) station.codec,
          if (station.bitrate > 0) '${station.bitrate} kbps',
        ].join(' · '),
        artUrl: artUrl,
      );
      await ref
          .read(playbackHistoryControllerProvider.notifier)
          .recordRadio(
            stationId: station.stationUuid.isEmpty
                ? station.streamUrl
                : station.stationUuid,
            name: station.name,
            country: station.country,
            artworkUrl: artUrl ?? '',
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.radio_play_error.tr())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPlayback = false);
      }
    }
  }

  void _showStationInfo(RadioStation station) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _StationInfoSheet(station: station),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final favoriteStations = ref.watch(radioFavoritesControllerProvider);
    final favoritesController = ref.read(
      radioFavoritesControllerProvider.notifier,
    );
    final isDesktop = useFlowDesktopShell(context);

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          // La cabecera comparte el margen lateral del listado, para que el
          // titulo quede a plomo con la primera tarjeta en ambos anchos.
          padding: isDesktop
              ? const EdgeInsets.fromLTRB(40, 26, 40, 0)
              : const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        LocaleKeys.radio.tr(),
                        // 30px en escritorio, como los titulos de seccion del
                        // mockup; 24px en movil, donde no cabe.
                        style:
                            (isDesktop
                                    ? theme.textTheme.headlineMedium
                                    : theme.textTheme.headlineSmall)
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colors.onSurface,
                                ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => context.go('/radio-map'),
                      icon: const Icon(Icons.travel_explore_rounded),
                      label: Text(LocaleKeys.radio_map_explorer_short.tr()),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (favoriteStations.isNotEmpty) ...[
                  _FavoriteStationStrip(
                    stations: favoriteStations,
                    playingStationUuid: _playingStationUuid,
                    playerState: _playerState,
                    onTap: (station) {
                      ref
                          .read(radioQueueControllerProvider.notifier)
                          .enqueue(
                            favoriteStations,
                            favoriteStations.indexOf(station),
                          );
                      _toggleStation(station);
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                _CountryFilters(
                  countries: _countryFilters,
                  selectedCountryCode: _selectedCountryCode,
                  onSelected: (countryCode) => _loadStations(
                    countryCode: countryCode == _selectedCountryCode
                        ? ''
                        : countryCode,
                  ),
                ),
                const SizedBox(height: 10),
                FutureBuilder<List<RadioTag>>(
                  future: _tagsFuture,
                  builder: (context, snapshot) {
                    final tags = snapshot.data ?? const <RadioTag>[];
                    if (tags.isEmpty) return const SizedBox.shrink();
                    return _TagFilters(
                      tags: tags,
                      selectedTag: _selectedTag,
                      onSelected: (tag) =>
                          _loadStations(tag: tag == _selectedTag ? '' : tag),
                    );
                  },
                ),
                if (_selectedTag.isNotEmpty ||
                    _selectedCountryCode.isNotEmpty ||
                    _lastSearchText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear_rounded),
                    label: Text(LocaleKeys.clear.tr()),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        FutureBuilder<List<RadioStation>>(
          future: _stationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                ),
              );
            }

            if (snapshot.hasError) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: _RadioMessage(
                  icon: Icons.wifi_off_rounded,
                  message: LocaleKeys.radio_error.tr(),
                  actionLabel: LocaleKeys.retry.tr(),
                  onAction: () => _loadStations(),
                ),
              );
            }

            final stations = snapshot.data ?? const <RadioStation>[];
            if (stations.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: _RadioMessage(
                  icon: Icons.radio_rounded,
                  message: LocaleKeys.no_radio_results.tr(),
                ),
              );
            }

            Future<void> toggleFavorite(RadioStation station) async {
              final added = await favoritesController.toggle(station);
              if (!context.mounted) return;
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(
                  content: Text(
                    added
                        ? LocaleKeys.radio_favorite_added.tr()
                        : LocaleKeys.radio_favorite_removed.tr(),
                  ),
                ),
              );
            }

            // En escritorio las emisoras van en cuadricula de tarjetas de color
            // (mockup "Radio — escritorio"); en movil siguen siendo filas.
            if (isDesktop) {
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
                sliver: SliverGrid.builder(
                  itemCount: stations.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    mainAxisExtent: 150,
                  ),
                  itemBuilder: (context, index) {
                    final station = stations[index];
                    return RadioStationCard(
                      station: station,
                      isActive: station.stationUuid == _playingStationUuid,
                      isFavorite: favoritesController.contains(station),
                      onTap: () {
                        ref
                            .read(radioQueueControllerProvider.notifier)
                            .enqueue(stations, index);
                        _toggleStation(station);
                      },
                      onToggleFavorite: () => toggleFavorite(station),
                    );
                  },
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.separated(
                itemCount: stations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final station = stations[index];
                  final isActive = station.stationUuid == _playingStationUuid;
                  final isFavorite = favoritesController.contains(station);
                  return _StationTile(
                    station: station,
                    isActive: isActive,
                    isFavorite: isFavorite,
                    isPlaying: isActive && _playerState == PlayerState.playing,
                    isLoading:
                        _isLoadingPlayback &&
                        station.stationUuid == _playingStationUuid,
                    onTap: () {
                      ref
                          .read(radioQueueControllerProvider.notifier)
                          .enqueue(stations, index);
                      _toggleStation(station);
                    },
                    onLongPress: () => _showStationInfo(station),
                    onToggleFavorite: () => toggleFavorite(station),
                    onAddToPlaylist: () => showAddToRadioPlaylistFlow(
                      context: context,
                      ref: ref,
                      station: station,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _FavoriteStationStrip extends StatelessWidget {
  const _FavoriteStationStrip({
    required this.stations,
    required this.playingStationUuid,
    required this.playerState,
    required this.onTap,
  });

  final List<RadioStation> stations;
  final String? playingStationUuid;
  final PlayerState playerState;
  final ValueChanged<RadioStation> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.favorite_stations.tr(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: stations.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final station = stations[index];
              final isActive = station.stationUuid == playingStationUuid;
              final flag = _countryFlagEmoji(station.countryCode);
              return ActionChip(
                avatar: isActive && playerState == PlayerState.playing
                    ? Icon(Icons.graphic_eq_rounded, color: colors.primary)
                    : flag.isEmpty
                    ? const Icon(Icons.radio_rounded)
                    : _FlagEmoji(flag: flag),
                label: Text(
                  station.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () => onTap(station),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CountryFilters extends StatelessWidget {
  const _CountryFilters({
    required this.countries,
    required this.selectedCountryCode,
    required this.onSelected,
  });

  final Map<String, String> countries;
  final String selectedCountryCode;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,

        children: countries.entries.map((entry) {
          final flag = _countryFlagEmoji(entry.key);
          return FilterChip(
            clipBehavior: Clip.antiAlias,
            selected: selectedCountryCode == entry.key,
            label: Text(entry.value),
            avatar: flag.isEmpty
                ? const Icon(Icons.public_rounded, size: 18)
                : _FlagEmoji(flag: flag),
            onSelected: (_) => onSelected(entry.key),
          );
        }).toList(),
      ),
    );
  }
}

class _TagFilters extends StatelessWidget {
  const _TagFilters({
    required this.tags,
    required this.selectedTag,
    required this.onSelected,
  });

  final List<RadioTag> tags;
  final String selectedTag;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tags.map((tag) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: selectedTag == tag.name,
              label: Text(tag.name),
              onSelected: (_) => onSelected(tag.name),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StationTile extends StatelessWidget {
  const _StationTile({
    required this.station,
    required this.isActive,
    required this.isFavorite,
    required this.isPlaying,
    required this.isLoading,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleFavorite,
    required this.onAddToPlaylist,
  });

  final RadioStation station;
  final bool isActive;
  final bool isFavorite;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAddToPlaylist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final extras = theme.extension<FlowThemeExtras>();
    final origin = station.country.isNotEmpty
        ? station.country
        : station.countryCode;
    final flag = _countryFlagEmoji(station.countryCode);
    final stationDetails = [
      if (origin.isNotEmpty) origin,
      if (station.codec.isNotEmpty) station.codec,
      if (station.bitrate > 0) '${station.bitrate} kbps',
    ].join(' · ');

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Ink(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? colors.primary
                : extras?.subtleStroke ?? colors.outline,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox.square(
                dimension: 58,
                child: station.artworkUrl.isEmpty
                    ? _RadioArtwork(colors: colors)
                    : Image.network(
                        station.artworkUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _RadioArtwork(colors: colors),
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
                    station.name.isEmpty ? LocaleKeys.radio.tr() : station.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (flag.isNotEmpty) ...[
                        _FlagEmoji(flag: flag, size: 16, dimension: 22),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          stationDetails,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: onToggleFavorite,
              icon: Icon(
                isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
              ),
              color: isFavorite ? colors.primary : colors.onSurfaceVariant,
              tooltip: isFavorite
                  ? LocaleKeys.remove_from_favorites.tr()
                  : LocaleKeys.add_to_favorites.tr(),
            ),
            IconButton(
              onPressed: onAddToPlaylist,
              icon: const Icon(Icons.playlist_add_rounded),
              color: colors.onSurfaceVariant,
              tooltip: LocaleKeys.add_to_radio_playlist.tr(),
            ),
            IconButton.filled(
              onPressed: onTap,
              icon: isLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
              tooltip: isPlaying ? LocaleKeys.pause.tr() : LocaleKeys.play.tr(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StationInfoSheet extends StatelessWidget {
  const _StationInfoSheet({required this.station});

  final RadioStation station;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final entries = station.rawData.entries.toList();

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          LocaleKeys.properties.tr(),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (station.name.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            station.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: Navigator.of(context).pop,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: colors.outlineVariant.withValues(alpha: 0.5),
                  ),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            _formatStationInfoValue(entry.value),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatStationInfoValue(Object? value) {
  if (value == null) return '-';
  if (value is String) return value.trim().isEmpty ? '-' : value;
  if (value is num || value is bool) return value.toString();

  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } catch (_) {
    return value.toString();
  }
}

class _RadioArtwork extends StatelessWidget {
  const _RadioArtwork({required this.colors});

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

class _RadioMessage extends StatelessWidget {
  const _RadioMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: colors.primary),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
