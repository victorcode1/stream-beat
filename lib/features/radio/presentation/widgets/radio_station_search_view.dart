import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/future_guard.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/home/presentation/providers/text_search.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/data/repositories/radio_browser_repository.dart';
import 'package:flow_music/features/radio/presentation/utils/play_radio_station.dart';
import 'package:flow_music/features/radio/presentation/widgets/radio_playlist_actions.dart';
import 'package:flow_music/features/radio/presentation/widgets/radio_station_tile.dart';
import 'package:flow_music/features/settings/presentation/pages/station_rights_page.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class RadioStationSearchView extends ConsumerStatefulWidget {
  const RadioStationSearchView({super.key, this.repository});

  final RadioBrowserRepository? repository;

  @override
  ConsumerState<RadioStationSearchView> createState() =>
      _RadioStationSearchViewState();
}

class _RadioStationSearchViewState
    extends ConsumerState<RadioStationSearchView> {
  static const _countries = <String, String>{
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

  late final RadioBrowserRepository _repository;
  late final bool _ownsRepository;
  late final TextEditingController _searchController;
  late Future<List<RadioStation>> _stationsFuture;
  Timer? _debounce;
  String _query = '';
  String _countryCode = '';

  @override
  void initState() {
    super.initState();
    _ownsRepository = widget.repository == null;
    _repository = widget.repository ?? RadioBrowserRepository();
    _searchController = ref.read(searchProvider);
    _query = _searchController.text.trim();
    _searchController.addListener(_onQueryChanged);
    _stationsFuture = _fetchStations();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onQueryChanged);
    if (_ownsRepository) _repository.close();
    super.dispose();
  }

  void _onQueryChanged() {
    final nextQuery = _searchController.text.trim();
    if (nextQuery == _query) return;

    _query = nextQuery;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reload);
  }

  Future<List<RadioStation>> _fetchStations() {
    if (_query.isEmpty && _countryCode.isEmpty) {
      return _repository.topStations(limit: 40).guarded();
    }

    return _repository
        .searchStations(name: _query, countryCode: _countryCode, limit: 60)
        .guarded();
  }

  void _reload() {
    if (!mounted) return;
    final stationsFuture = _fetchStations();
    setState(() {
      _stationsFuture = stationsFuture;
    });
  }

  void _selectCountry(String countryCode) {
    setState(() {
      _countryCode = _countryCode == countryCode ? '' : countryCode;
      _stationsFuture = _fetchStations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StationDirectoryAttribution(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(
            LocaleKeys.filter_by_country.tr(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _countries.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final entry = _countries.entries.elementAt(index);
              final flag = _countryFlagEmoji(entry.key);
              return FilterChip(
                selected: _countryCode == entry.key,
                avatar: Text(flag, style: const TextStyle(fontSize: 17)),
                label: Text(entry.value),
                onSelected: (_) => _selectCountry(entry.key),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Divider(height: 1, color: colors.outlineVariant),
        Expanded(
          child: FutureBuilder<List<RadioStation>>(
            future: _stationsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                );
              }

              if (snapshot.hasError) {
                return _SearchMessage(
                  icon: Icons.wifi_off_rounded,
                  message: LocaleKeys.radio_error.tr(),
                  actionLabel: LocaleKeys.retry.tr(),
                  onAction: _reload,
                );
              }

              final stations = snapshot.data ?? const <RadioStation>[];
              if (stations.isEmpty) {
                return _SearchMessage(
                  icon: Icons.search_off_rounded,
                  message: LocaleKeys.no_radio_results.tr(),
                );
              }

              return ListView.separated(
                clipBehavior: Clip.hardEdge,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: stations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final station = stations[index];
                  return RadioStationTile(
                    station: station,
                    onTap: () => unawaited(
                      playRadioStation(
                        context: context,
                        ref: ref,
                        station: station,
                        queue: stations,
                        index: index,
                      ),
                    ),
                    onAddToPlaylist: () => unawaited(
                      showAddToRadioPlaylistFlow(
                        context: context,
                        ref: ref,
                        station: station,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

String _countryFlagEmoji(String countryCode) {
  final normalized = countryCode.trim().toUpperCase();
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(normalized)) return '';

  const regionalIndicatorA = 0x1F1E6;
  const asciiA = 0x41;
  return String.fromCharCodes([
    regionalIndicatorA + normalized.codeUnitAt(0) - asciiA,
    regionalIndicatorA + normalized.codeUnitAt(1) - asciiA,
  ]);
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({
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
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colors.primary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
