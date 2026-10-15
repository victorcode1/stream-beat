import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/audio/background_audio_handler.dart';
import 'package:flow_music/core/theme/custom_theme.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/core/utils/search_text_normalizer.dart';
import 'package:flow_music/features/home/data/location_service.dart';
import 'package:flow_music/features/home/presentation/providers/text_search.dart';
import 'package:flow_music/features/radio/data/models/radio_country.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/data/repositories/country_catalog_repository.dart';
import 'package:flow_music/features/radio/data/repositories/radio_browser_repository.dart';
import 'package:flow_music/features/radio/presentation/controllers/radio_favorites_controller.dart';
import 'package:flow_music/features/radio/presentation/controllers/radio_queue_controller.dart';
import 'package:flow_music/features/radio/presentation/utils/play_radio_station.dart';
import 'package:flow_music/features/radio/presentation/widgets/particles_fly.dart';
import 'package:flow_music/features/radio/presentation/widgets/radio_playlist_actions.dart';
import 'package:flow_music/features/radio/presentation/widgets/station_links.dart';
import 'package:flow_music/shared/widgets/optimized_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:latlong2/latlong.dart';

final RegExp _countryCodePattern = RegExp(r'^[A-Z]{2}$');
const String _naturalEarthMapAsset =
    'assets/maps/ne_110m_admin_0_countries.geojson';

class _WorldPolygon {
  const _WorldPolygon({required this.points, required this.holes});

  final List<LatLng> points;
  final List<List<LatLng>> holes;
}

Future<List<_WorldPolygon>> _loadWorldPolygons() async {
  final source = await rootBundle.loadString(_naturalEarthMapAsset);
  final collection = jsonDecode(source) as Map<String, dynamic>;
  final features = collection['features'] as List<dynamic>? ?? const [];
  final polygons = <_WorldPolygon>[];

  for (final feature in features.whereType<Map<String, dynamic>>()) {
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    if (geometry == null) continue;

    final coordinates = geometry['coordinates'];
    switch (geometry['type']) {
      case 'Polygon':
        _appendWorldPolygon(polygons, coordinates);
      case 'MultiPolygon':
        if (coordinates is List<dynamic>) {
          for (final polygonCoordinates in coordinates) {
            _appendWorldPolygon(polygons, polygonCoordinates);
          }
        }
    }
  }

  return List.unmodifiable(polygons);
}

void _appendWorldPolygon(List<_WorldPolygon> polygons, dynamic rawCoordinates) {
  if (rawCoordinates is! List<dynamic> || rawCoordinates.isEmpty) return;

  final points = _decodeGeoJsonRing(rawCoordinates.first);
  if (points.length < 3) return;

  final holes = rawCoordinates
      .skip(1)
      .map(_decodeGeoJsonRing)
      .where((ring) => ring.length >= 3)
      .toList(growable: false);
  polygons.add(_WorldPolygon(points: points, holes: holes));
}

List<LatLng> _decodeGeoJsonRing(dynamic rawRing) {
  if (rawRing is! List<dynamic>) return const [];

  return rawRing
      .whereType<List<dynamic>>()
      .where((pair) => pair.length >= 2)
      .map(
        (pair) =>
            LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble()),
      )
      .toList(growable: false);
}

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

String _stationPlaybackId(RadioStation station) =>
    station.stationUuid.isEmpty ? station.streamUrl : station.stationUuid;

String _normalizeCountryQuery(String value) {
  return normalizeSearchText(value);
}

class RadioMapExplorerPage extends ConsumerStatefulWidget {
  const RadioMapExplorerPage({super.key});

  @override
  ConsumerState<RadioMapExplorerPage> createState() =>
      _RadioMapExplorerPageState();
}

class _RadioMapExplorerPageState extends ConsumerState<RadioMapExplorerPage> {
  static const _initialCenter = LatLng(12, 0);
  static const _initialZoom = 1.62;
  static const _locationZoom = 5.65;
  static const _maxVisibleCountries = 14;
  static const _stationsPerCountry = 30;
  static const _sheetInitialChildSize = 0.34;
  static const _sheetMinChildSize = 0.22;
  static const _sheetMaxChildSize = 0.74;

  final RadioBrowserRepository _repository = RadioBrowserRepository();
  final CountryCatalogRepository _countryCatalogRepository =
      CountryCatalogRepository();
  final LocationService _locationService = const LocationService();
  final MapController _mapController = MapController();
  late final TextEditingController _searchController;
  final Map<String, List<RadioStation>> _countryStationCache = {};
  final Map<String, Future<List<RadioStation>>> _pendingCountryLoads = {};

  StreamSubscription<PlayerState>? _playerStateSubscription;
  Timer? _mapDebounce;
  Timer? _searchDebounce;
  int _loadToken = 0;
  String _visibleCountryKey = '';
  String? _playingStationUuid;
  PlayerState _playerState = PlayerState.stopped;
  bool _isLoadingPlayback = false;
  bool _isLoadingStations = true;
  bool _isSearching = false;
  bool _didResolveInitialLocation = false;
  bool _isMapReady = false;
  double _mapZoom = _initialZoom;
  String? _errorMessage;
  RadioCountry? _selectedCountry;
  List<RadioCountry> _visibleCountries = const [];
  List<RadioCountry> _markerCountries = const [];
  List<RadioCountry> _countryCatalog = radioCountries;
  List<RadioStation> _stations = const [];

  @override
  void initState() {
    super.initState();
    _searchController = ref.read(searchProvider);
    _playerState = flowAudioHandler.player.state;
    _playerStateSubscription = flowAudioHandler.player.onPlayerStateChanged
        .listen((state) {
          if (mounted) {
            setState(() {
              _playerState = state;
              if (state == PlayerState.playing) {
                _playingStationUuid = flowAudioHandler.mediaItem.value?.id;
              }
            });
          }
        });
    _searchController.addListener(_onSearchChanged);
    _loadCountryCatalog();
  }

  @override
  void dispose() {
    _mapDebounce?.cancel();
    _searchDebounce?.cancel();
    _playerStateSubscription?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _repository.close();
    _countryCatalogRepository.close();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapReady() {
    _isMapReady = true;
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _moveToInitialLocation();
    } else {
      _runSearch(query);
    }
  }

  Future<void> _loadCountryCatalog() async {
    final countries = await _countryCatalogRepository.countries();
    if (!mounted) return;

    setState(() => _countryCatalog = countries);
    if (_isMapReady && _searchController.text.trim().isEmpty) {
      _loadCountriesForCamera(_mapController.camera, force: true);
    }
  }

  Future<void> _moveToInitialLocation() async {
    if (_didResolveInitialLocation) {
      _loadCountriesForCamera(_mapController.camera, force: true);
      return;
    }

    _didResolveInitialLocation = true;
    final accessStatus = await _locationService.locationAccessStatus();
    if (!mounted) return;

    if (accessStatus != LocationAccessStatus.available) {
      await _showLocationAccessPrompt(accessStatus);
      if (!mounted) return;

      final refreshedStatus = await _locationService.locationAccessStatus();
      if (!mounted) return;
      if (refreshedStatus != LocationAccessStatus.available) {
        _loadCountriesForCamera(_mapController.camera, force: true);
        return;
      }
    }

    final location = await _locationService.resolveLocation(
      timeLimit: const Duration(seconds: 4),
    );
    if (!mounted) return;

    if (location.isResolved) {
      _mapController.move(
        LatLng(location.latitude!, location.longitude!),
        _locationZoom,
      );
    }

    _loadCountriesForCamera(_mapController.camera, force: true);
  }

  Future<void> _showLocationAccessPrompt(LocationAccessStatus status) async {
    if (status == LocationAccessStatus.webUnsupported) return;

    final copy = switch (status) {
      LocationAccessStatus.serviceDisabled => (
        title: LocaleKeys.location_enable_title.tr(),
        message: LocaleKeys.location_enable_message.tr(),
        action: LocaleKeys.location_open_settings.tr(),
      ),
      LocationAccessStatus.permissionDenied => (
        title: LocaleKeys.location_allow_title.tr(),
        message: LocaleKeys.location_allow_message.tr(),
        action: LocaleKeys.location_allow_action.tr(),
      ),
      LocationAccessStatus.permissionDeniedForever => (
        title: LocaleKeys.location_blocked_title.tr(),
        message: LocaleKeys.location_blocked_message.tr(),
        action: LocaleKeys.location_open_settings.tr(),
      ),
      LocationAccessStatus.available || LocationAccessStatus.webUnsupported => (
        title: '',
        message: '',
        action: '',
      ),
    };

    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.location_on_rounded),
          title: Text(copy.title),
          content: Text(copy.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(LocaleKeys.not_now.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(copy.action),
            ),
          ],
        );
      },
    );
    if (!mounted || shouldContinue != true) return;

    switch (status) {
      case LocationAccessStatus.permissionDenied:
        final result = await _locationService.requestLocationAccess();
        if (!mounted) return;
        if (result != LocationAccessStatus.available) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocaleKeys.location_permission_still_denied.tr()),
            ),
          );
        }
      case LocationAccessStatus.permissionDeniedForever:
        await _locationService.openAppLocationSettings();
      case LocationAccessStatus.serviceDisabled:
        await _locationService.openDeviceLocationSettings();
      case LocationAccessStatus.available:
      case LocationAccessStatus.webUnsupported:
        break;
    }
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if ((camera.zoom - _mapZoom).abs() >= 0.05 && mounted) {
      setState(() => _mapZoom = camera.zoom);
    }
    if (_searchController.text.trim().isNotEmpty) return;

    _mapDebounce?.cancel();
    _mapDebounce = Timer(const Duration(milliseconds: 650), () {
      _loadCountriesForCamera(camera);
    });
  }

  Future<void> _loadCountriesForCamera(
    MapCamera camera, {
    bool force = false,
  }) async {
    final countries = _countriesForCamera(camera);
    final countryKey = countries.map((country) => country.code).join(',');
    if (!force && countryKey == _visibleCountryKey && _errorMessage == null) {
      return;
    }

    _visibleCountryKey = countryKey;
    final token = ++_loadToken;

    setState(() {
      _isSearching = false;
      _isLoadingStations = true;
      _errorMessage = null;
      _visibleCountries = countries;
      _selectedCountry = null;
    });

    try {
      final stationGroups = await Future.wait(
        countries.map(_stationsForCountry),
      );
      if (!mounted || token != _loadToken) return;

      final loadedCountries = <RadioCountry>[];
      final stations = <RadioStation>[];
      for (var i = 0; i < countries.length; i++) {
        final group = stationGroups[i];
        if (group.isEmpty) continue;
        loadedCountries.add(countries[i]);
        stations.addAll(group);
      }

      setState(() {
        _markerCountries = loadedCountries;
        _stations = stations;
        _isLoadingStations = false;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _errorMessage = LocaleKeys.radio_map_error.tr();
        _isLoadingStations = false;
      });
    }
  }

  List<RadioCountry> _countriesForCamera(MapCamera camera) {
    final bounds = camera.visibleBounds;
    final center = camera.center;
    final latitudePadding = math.max(2.5, (bounds.north - bounds.south) * 0.18);
    final longitudePadding = math.max(
      3.5,
      (bounds.east - bounds.west).abs() * 0.2,
    );
    final paddedSouth = (bounds.south - latitudePadding).clamp(-90.0, 90.0);
    final paddedNorth = (bounds.north + latitudePadding).clamp(-90.0, 90.0);
    final paddedWest = bounds.west - longitudePadding;
    final paddedEast = bounds.east + longitudePadding;
    final countries =
        _countryCatalog
            .where(
              (country) => country.intersects(
                boundsSouth: paddedSouth,
                boundsWest: paddedWest,
                boundsNorth: paddedNorth,
                boundsEast: paddedEast,
              ),
            )
            .toList()
          ..sort(
            (a, b) => a
                .distanceScore(center.latitude, center.longitude)
                .compareTo(b.distanceScore(center.latitude, center.longitude)),
          );

    return countries.take(_maxVisibleCountries).toList(growable: false);
  }

  Future<List<RadioStation>> _stationsForCountry(RadioCountry country) {
    final cached = _countryStationCache[country.code];
    if (cached != null) return Future.value(cached);

    final pending = _pendingCountryLoads[country.code];
    if (pending != null) return pending;

    final future = _repository
        .searchStations(countryCode: country.code, limit: _stationsPerCountry)
        .then((stations) {
          _countryStationCache[country.code] = stations;
          _pendingCountryLoads.remove(country.code);
          return stations;
        })
        .catchError((Object error) {
          _pendingCountryLoads.remove(country.code);
          throw error;
        });

    _pendingCountryLoads[country.code] = future;
    return future;
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _runSearch(_searchController.text);
    });
  }

  Future<void> _runSearch(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      _loadCountriesForCamera(_mapController.camera, force: true);
      return;
    }

    final country = _findCountry(query);
    if (country != null) {
      _moveToCountry(country);
      await _selectCountry(country, moveMap: false);
      return;
    }

    final token = ++_loadToken;
    setState(() {
      _isSearching = true;
      _isLoadingStations = true;
      _errorMessage = null;
      _selectedCountry = null;
    });

    try {
      final stations = await _repository.searchStations(name: query, limit: 36);
      if (!mounted || token != _loadToken) return;

      final countries = stations
          .map((station) => _findCountryByCode(station.countryCode))
          .whereType<RadioCountry>()
          .fold<List<RadioCountry>>([], (list, country) {
            if (!list.any((item) => item.code == country.code)) {
              list.add(country);
            }
            return list;
          });

      setState(() {
        _stations = stations;
        _markerCountries = countries;
        _visibleCountries = countries;
        _isLoadingStations = false;
      });

      if (countries.isNotEmpty) {
        _moveToCountry(countries.first, zoom: 4.3);
      }
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _errorMessage = LocaleKeys.radio_map_error.tr();
        _isLoadingStations = false;
      });
    }
  }

  Future<void> _selectCountry(
    RadioCountry country, {
    bool moveMap = true,
  }) async {
    final token = ++_loadToken;
    if (moveMap) _moveToCountry(country);

    setState(() {
      _selectedCountry = country;
      _isSearching = false;
      _isLoadingStations = true;
      _errorMessage = null;
      _visibleCountries = [country];
    });

    try {
      final stations = await _stationsForCountry(country);
      if (!mounted || token != _loadToken) return;

      setState(() {
        _stations = stations;
        _markerCountries = stations.isEmpty ? const [] : [country];
        _isLoadingStations = false;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _errorMessage = LocaleKeys.radio_map_error.tr();
        _isLoadingStations = false;
      });
    }
  }

  void _moveToCountry(RadioCountry country, {double zoom = 5}) {
    _mapController.move(LatLng(country.latitude, country.longitude), zoom);
  }

  void _resetWorld() {
    _searchController.clear();
    _selectedCountry = null;
    _mapController.move(_initialCenter, _initialZoom);
    _loadCountriesForCamera(_mapController.camera, force: true);
  }

  RadioCountry? _findCountry(String query) {
    final normalized = _normalizeCountryQuery(query);
    if (normalized.isEmpty) return null;

    for (final country in _countryCatalog) {
      if (_normalizeCountryQuery(country.code) == normalized ||
          _normalizeCountryQuery(country.name) == normalized) {
        return country;
      }
    }

    for (final country in _countryCatalog) {
      if (_normalizeCountryQuery(country.name).contains(normalized)) {
        return country;
      }
    }

    return findRadioCountry(query);
  }

  RadioCountry? _findCountryByCode(String code) {
    final normalized = code.trim().toUpperCase();
    for (final country in _countryCatalog) {
      if (country.code == normalized) return country;
    }
    return findRadioCountryByCode(code);
  }

  Future<void> _selectStation(RadioStation station) async {
    final isCurrentStation = _stationPlaybackId(station) == _playingStationUuid;
    if (isCurrentStation && _playerState == PlayerState.playing) return;
    await _playStation(station);
  }

  Future<void> _playStation(RadioStation station) async {
    if (!station.isPlayable || _isLoadingPlayback) return;

    setState(() {
      _isLoadingPlayback = true;
      _playingStationUuid = _stationPlaybackId(station);
    });

    final stations = _stationsForSheet;
    final selectedIndex = stations.indexWhere(
      (candidate) =>
          _stationPlaybackId(candidate) == _stationPlaybackId(station),
    );
    ref
        .read(radioQueueControllerProvider.notifier)
        .enqueue(
          selectedIndex == -1 ? [station] : stations,
          selectedIndex == -1 ? 0 : selectedIndex,
        );
    final succeeded = await playRadioStation(
      context: context,
      ref: ref,
      station: station,
      repository: _repository,
    );
    if (mounted) {
      if (!succeeded && _playingStationUuid == _stationPlaybackId(station)) {
        _playingStationUuid = null;
      }
      setState(() => _isLoadingPlayback = false);
    }
  }

  RadioStation? _activeStation(List<RadioStation> favoriteStations) {
    final id = _playingStationUuid;
    if (id == null || id.isEmpty) return null;

    for (final station in [
      ..._stations,
      for (final group in _countryStationCache.values) ...group,
      ...favoriteStations,
    ]) {
      if (_stationPlaybackId(station) == id) return station;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final favoriteStations = ref.watch(radioFavoritesControllerProvider);
    final favoritesController = ref.read(
      radioFavoritesControllerProvider.notifier,
    );
    final reservedSheetHeight = (mediaQuery.size.height * _sheetMinChildSize)
        .clamp(150.0, 220.0);
    final sheetBottomInset = mediaQuery.padding.bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.surfaceContainerLowest,
            colors.surfaceContainerLowest,
            colors.primary.withValues(alpha: 0.22),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: ParticlesFly(
                  numberOfParticles: isDark ? 132 : 126,
                  speedOfParticles: 0.2,
                  maxParticleSize: isDark ? 1.55 : 1.6,
                  intensity: isDark ? 1 : 1.45,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, 0.08),
                      radius: 1.05,
                      colors: [
                        colors.primary.withValues(alpha: isDark ? 0.08 : 0.12),
                        Colors.transparent,
                        colors.secondary.withValues(
                          alpha: isDark ? 0.02 : 0.06,
                        ),
                      ],
                      stops: const [0.0, 0.52, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                bottom: reservedSheetHeight + sheetBottomInset,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final title = Text(
                          LocaleKeys.radio_map_explorer.tr(),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: colors.onSurface,
                          ),
                        );
                        final resetButton = TextButton.icon(
                          onPressed: _resetWorld,
                          icon: const Icon(Icons.public_rounded),
                          label: Text(LocaleKeys.radio_map_back_world.tr()),
                          style: TextButton.styleFrom(
                            foregroundColor: colors.primary,
                            textStyle: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        );
                        if (constraints.maxWidth < 560) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              title,
                              Align(
                                alignment: Alignment.centerRight,
                                child: resetButton,
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: title),
                            resetButton,
                          ],
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const SizedBox(height: 4),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final maxGlobeSize = math
                                  .min(
                                    constraints.maxWidth - 24,
                                    constraints.maxHeight - 8,
                                  )
                                  .clamp(0.0, 620.0);
                              final globeSize = maxGlobeSize >= 260
                                  ? maxGlobeSize
                                  : math.max(0.0, maxGlobeSize);

                              return Align(
                                alignment: Alignment.topCenter,
                                child: SizedBox.square(
                                  dimension: globeSize,
                                  child: _GlobeMap(
                                    mapController: _mapController,
                                    markers: _buildMarkers(context),
                                    onMapReady: _onMapReady,
                                    onPositionChanged: _onPositionChanged,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _StationsSheet(
                stations: _stationsForSheet,
                visibleCountries: _visibleCountries,
                selectedCountry: _selectedCountry,
                title: _sheetTitle,
                activeStation: _activeStation(favoriteStations),
                favoriteStations: favoriteStations,
                isLoading: _isLoadingStations,
                errorMessage: _errorMessage,
                isSearching: _isSearching,
                initialChildSize: _sheetInitialChildSize,
                minChildSize: _sheetMinChildSize,
                maxChildSize: _sheetMaxChildSize,
                onRetry: () =>
                    _loadCountriesForCamera(_mapController.camera, force: true),
                playingStationUuid: _playingStationUuid,
                playerState: _playerState,
                isLoadingPlayback: _isLoadingPlayback,
                onStationTap: _selectStation,
                onFavoriteToggle: (station) async {
                  final added = await favoritesController.toggle(station);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        added
                            ? LocaleKeys.radio_favorite_added.tr()
                            : LocaleKeys.radio_favorite_removed.tr(),
                      ),
                    ),
                  );
                },
                onAddToPlaylist: (station) => showAddToRadioPlaylistFlow(
                  context: context,
                  ref: ref,
                  station: station,
                ),
                onCountrySelected: (country) =>
                    _selectCountry(country, moveMap: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<RadioStation> get _stationsForSheet {
    final selected = _selectedCountry;
    if (selected == null) return _stations;
    return _countryStationCache[selected.code] ?? _stations;
  }

  String get _sheetTitle {
    final selected = _selectedCountry;
    if (selected != null) {
      return '${LocaleKeys.radio_map_available.tr()} · ${selected.name}';
    }
    return LocaleKeys.radio_map_available.tr();
  }

  List<Marker> _buildMarkers(BuildContext context) {
    if (_mapZoom < 2.65 && _selectedCountry == null) return const [];

    return _markerCountries
        .map((country) {
          final stations =
              _countryStationCache[country.code] ??
              _stations
                  .where((station) => station.countryCode == country.code)
                  .toList(growable: false);
          final count = stations.length;
          if (count == 0) return null;

          return Marker(
            point: _markerPoint(country, stations),
            width: 108,
            height: 58,
            alignment: Alignment.center,
            child: _CountryMarker(
              country: country,
              stationCount: count,
              isSelected: _selectedCountry?.code == country.code,
              onTap: () => _selectCountry(country, moveMap: false),
            ),
          );
        })
        .whereType<Marker>()
        .toList(growable: false);
  }

  LatLng _markerPoint(RadioCountry country, List<RadioStation> stations) {
    RadioStation? geoStation;
    for (final station in stations) {
      if (station.hasGeoPoint) {
        geoStation = station;
        break;
      }
    }

    if (geoStation != null) {
      return LatLng(geoStation.latitude!, geoStation.longitude!);
    }

    return LatLng(country.latitude, country.longitude);
  }
}

class _GlobeMap extends StatefulWidget {
  const _GlobeMap({
    required this.mapController,
    required this.markers,
    required this.onMapReady,
    required this.onPositionChanged,
  });

  final MapController mapController;
  final List<Marker> markers;
  final VoidCallback onMapReady;
  final void Function(MapCamera camera, bool hasGesture) onPositionChanged;

  @override
  State<_GlobeMap> createState() => _GlobeMapState();
}

class _GlobeMapState extends State<_GlobeMap> {
  late final Future<List<_WorldPolygon>> _worldPolygons = _loadWorldPolygons();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mapBackground = isDark
        ? const Color(0xFF071A1B)
        : const Color(0xFFEAF7F8);
    final landColor = isDark
        ? const Color(0xFF164B4D)
        : const Color(0xFFB5E1DE);
    final borderColor = colors.primary.withValues(alpha: isDark ? 0.38 : 0.5);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: isDark ? 0.28 : 0.2),
                  blurRadius: isDark ? 44 : 52,
                  spreadRadius: isDark ? 3 : 8,
                ),
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.75)
                      : colors.primary.withValues(alpha: 0.12),
                  blurRadius: isDark ? 34 : 42,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.28, -0.24),
                        radius: 1.04,
                        colors: isDark
                            ? const [Color(0xFF0A1B1D), Color(0xFF041012)]
                            : const [Color(0xFFF8FEFF), Color(0xFFD9EFF1)],
                      ),
                    ),
                  ),
                  RepaintBoundary(
                    child: FlutterMap(
                      mapController: widget.mapController,
                      options: MapOptions(
                        initialCenter:
                            _RadioMapExplorerPageState._initialCenter,
                        initialZoom: _RadioMapExplorerPageState._initialZoom,
                        minZoom: 1.1,
                        maxZoom: 12,
                        backgroundColor: mapBackground,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                        onMapReady: widget.onMapReady,
                        onPositionChanged: widget.onPositionChanged,
                      ),
                      children: [
                        FutureBuilder<List<_WorldPolygon>>(
                          future: _worldPolygons,
                          builder: (context, snapshot) {
                            final worldPolygons = snapshot.data;
                            if (worldPolygons == null) {
                              return const SizedBox.shrink();
                            }

                            return PolygonLayer<Object>(
                              polygonLabels: false,
                              drawInSingleWorld: true,
                              polygons: worldPolygons
                                  .map(
                                    (polygon) => Polygon<Object>(
                                      points: polygon.points,
                                      holePointsList: polygon.holes.isEmpty
                                          ? null
                                          : polygon.holes,
                                      color: landColor,
                                      borderColor: borderColor,
                                      borderStrokeWidth: 0.55,
                                    ),
                                  )
                                  .toList(growable: false),
                            );
                          },
                        ),
                        MarkerLayer(markers: widget.markers),
                      ],
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 20,
                    child: IgnorePointer(
                      child: Center(
                        child: Text(
                          'Natural Earth',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.35, -0.38),
                          radius: 0.88,
                          colors: isDark
                              ? [
                                  Colors.transparent,
                                  colors.primary.withValues(alpha: 0.03),
                                  Colors.black.withValues(alpha: 0.64),
                                ]
                              : [
                                  Colors.white.withValues(alpha: 0.05),
                                  colors.primary.withValues(alpha: 0.07),
                                  colors.primary.withValues(alpha: 0.16),
                                ],
                          stops: const [0.0, 0.58, 1.0],
                        ),
                      ),
                    ),
                  ),
                  if (!isDark)
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: const Alignment(-0.2, -0.2),
                            radius: 0.95,
                            colors: [
                              Colors.transparent,
                              colors.secondary.withValues(alpha: 0.03),
                              colors.primary.withValues(alpha: 0.12),
                            ],
                            stops: const [0.0, 0.68, 1.0],
                          ),
                        ),
                      ),
                    ),
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.42),
                          width: 1.3,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: IgnorePointer(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.primary.withValues(alpha: 0.72),
                            width: 2,
                          ),
                          color: Colors.black.withValues(alpha: 0.28),
                        ),
                        child: Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primary.withValues(alpha: 0.9),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VisibleCountriesBar extends StatelessWidget {
  const _VisibleCountriesBar({
    required this.countries,
    required this.selectedCountry,
    required this.onSelected,
  });

  final List<RadioCountry> countries;
  final RadioCountry? selectedCountry;
  final ValueChanged<RadioCountry> onSelected;

  @override
  Widget build(BuildContext context) {
    if (countries.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: countries
            .map((country) {
              final selected = selectedCountry?.code == country.code;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: selected,
                  showCheckmark: false,
                  avatar: Text(_countryFlagEmoji(country.code)),
                  label: Text(
                    country.name,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected ? colors.onPrimary : colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  labelPadding: const EdgeInsets.only(right: 4),
                  side: BorderSide(
                    color: selected ? colors.primary : colors.outlineVariant,
                  ),
                  backgroundColor: colors.surfaceContainerLowest.withValues(
                    alpha: 0.96,
                  ),
                  selectedColor: colors.primary,
                  onSelected: (_) => onSelected(country),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _CountryMarker extends StatelessWidget {
  const _CountryMarker({
    required this.country,
    required this.stationCount,
    required this.isSelected,
    required this.onTap,
  });

  final RadioCountry country;
  final int stationCount;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final extras = theme.extension<FlowThemeExtras>();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? extras?.primaryGradient : null,
          color: isSelected ? null : colors.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? colors.primary : colors.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _countryFlagEmoji(country.code),
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                country.code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isSelected ? colors.onPrimary : colors.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: (isSelected ? colors.onPrimary : colors.primary)
                    .withValues(alpha: isSelected ? 0.22 : 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$stationCount',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected ? colors.onPrimary : colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator.adaptive(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(colors.primary),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: colors.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

enum _QuickStationFilter {
  nearby,
  pop,
  salsa,
  reggaeton,
  news,
  sports,
  top,
  favorites,
}

enum _RegionFilter {
  centralAmerica,
  caribbean,
  southAmerica,
  northAmerica,
  europe,
}

String _quickStationFilterLabel(_QuickStationFilter filter) => switch (filter) {
  _QuickStationFilter.nearby => LocaleKeys.filter_nearby.tr(),
  _QuickStationFilter.pop => LocaleKeys.category_pop.tr(),
  _QuickStationFilter.salsa => 'Salsa',
  _QuickStationFilter.reggaeton => LocaleKeys.category_reggaeton.tr(),
  _QuickStationFilter.news => LocaleKeys.filter_news.tr(),
  _QuickStationFilter.sports => LocaleKeys.filter_sports.tr(),
  _QuickStationFilter.top => LocaleKeys.filter_top.tr(),
  _QuickStationFilter.favorites => LocaleKeys.filter_favorites.tr(),
};

const _quickStationFilterIcons = {
  _QuickStationFilter.nearby: Icons.near_me_rounded,
  _QuickStationFilter.pop: Icons.graphic_eq_rounded,
  _QuickStationFilter.salsa: Icons.music_note_rounded,
  _QuickStationFilter.reggaeton: Icons.headphones_rounded,
  _QuickStationFilter.news: Icons.newspaper_rounded,
  _QuickStationFilter.sports: Icons.sports_soccer_rounded,
  _QuickStationFilter.top: Icons.trending_up_rounded,
  _QuickStationFilter.favorites: Icons.favorite_rounded,
};

String _regionFilterLabel(_RegionFilter filter) => switch (filter) {
  _RegionFilter.centralAmerica => LocaleKeys.region_central_america.tr(),
  _RegionFilter.caribbean => LocaleKeys.region_caribbean.tr(),
  _RegionFilter.southAmerica => LocaleKeys.region_south_america.tr(),
  _RegionFilter.northAmerica => LocaleKeys.region_north_america.tr(),
  _RegionFilter.europe => LocaleKeys.region_europe.tr(),
};

const _regionCountryCodes = {
  _RegionFilter.centralAmerica: {'BZ', 'CR', 'SV', 'GT', 'HN', 'NI', 'PA'},
  _RegionFilter.caribbean: {
    'AG',
    'AI',
    'AW',
    'BB',
    'BL',
    'BQ',
    'BS',
    'CU',
    'CW',
    'DM',
    'DO',
    'GD',
    'GP',
    'HT',
    'JM',
    'KN',
    'KY',
    'LC',
    'MF',
    'MQ',
    'MS',
    'PR',
    'SX',
    'TC',
    'TT',
    'VC',
    'VG',
    'VI',
  },
  _RegionFilter.southAmerica: {
    'AR',
    'BO',
    'BR',
    'CL',
    'CO',
    'EC',
    'FK',
    'GF',
    'GY',
    'PE',
    'PY',
    'SR',
    'UY',
    'VE',
  },
  _RegionFilter.northAmerica: {'BM', 'CA', 'GL', 'MX', 'PM', 'US'},
  _RegionFilter.europe: {
    'AD',
    'AL',
    'AT',
    'BA',
    'BE',
    'BG',
    'BY',
    'CH',
    'CY',
    'CZ',
    'DE',
    'DK',
    'EE',
    'ES',
    'FI',
    'FO',
    'FR',
    'GB',
    'GG',
    'GI',
    'GR',
    'HR',
    'HU',
    'IE',
    'IM',
    'IS',
    'IT',
    'JE',
    'LI',
    'LT',
    'LU',
    'LV',
    'MC',
    'MD',
    'ME',
    'MK',
    'MT',
    'NL',
    'NO',
    'PL',
    'PT',
    'RO',
    'RS',
    'SE',
    'SI',
    'SK',
    'SM',
    'UA',
    'VA',
  },
};

class _StationsSheet extends StatefulWidget {
  const _StationsSheet({
    required this.stations,
    required this.visibleCountries,
    required this.selectedCountry,
    required this.title,
    required this.activeStation,
    required this.favoriteStations,
    required this.isLoading,
    required this.errorMessage,
    required this.isSearching,
    required this.initialChildSize,
    required this.minChildSize,
    required this.maxChildSize,
    required this.onRetry,
    required this.playingStationUuid,
    required this.playerState,
    required this.isLoadingPlayback,
    required this.onStationTap,
    required this.onFavoriteToggle,
    required this.onAddToPlaylist,
    required this.onCountrySelected,
  });

  final List<RadioStation> stations;
  final List<RadioCountry> visibleCountries;
  final RadioCountry? selectedCountry;
  final String title;
  final RadioStation? activeStation;
  final List<RadioStation> favoriteStations;
  final bool isLoading;
  final String? errorMessage;
  final bool isSearching;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final VoidCallback onRetry;
  final String? playingStationUuid;
  final PlayerState playerState;
  final bool isLoadingPlayback;
  final ValueChanged<RadioStation> onStationTap;
  final ValueChanged<RadioStation> onFavoriteToggle;
  final ValueChanged<RadioStation> onAddToPlaylist;
  final ValueChanged<RadioCountry> onCountrySelected;

  @override
  State<_StationsSheet> createState() => _StationsSheetState();
}

class _StationsSheetState extends State<_StationsSheet> {
  _QuickStationFilter? _quickFilter;
  _RegionFilter? _regionFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final filteredStations = _filteredStations;

    return DraggableScrollableSheet(
      initialChildSize: widget.initialChildSize,
      minChildSize: widget.minChildSize,
      maxChildSize: widget.maxChildSize,
      expand: false,
      snap: true,
      builder: (context, scrollController) {
        return Material(
          color: colors.surface,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.outlineVariant)),
            ),
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colors.outlineVariant,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (filteredStations.isNotEmpty)
                              Text(
                                '${filteredStations.length}',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                          ],
                        ),
                        if (widget.activeStation != null) ...[
                          const SizedBox(height: 14),
                          _NowPlayingStationCard(
                            station: widget.activeStation!,
                            isPlaying:
                                widget.playerState == PlayerState.playing,
                            isLoading:
                                widget.isLoadingPlayback &&
                                widget.activeStation!.stationUuid ==
                                    widget.playingStationUuid,
                            onTap: () =>
                                widget.onStationTap(widget.activeStation!),
                          ),
                        ],
                        const SizedBox(height: 14),
                        _QuickFiltersBar(
                          selectedFilter: _quickFilter,
                          onSelected: (filter) {
                            setState(() {
                              _quickFilter = _quickFilter == filter
                                  ? null
                                  : filter;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _RegionFiltersBar(
                          selectedFilter: _regionFilter,
                          onSelected: (filter) {
                            setState(() {
                              _regionFilter = _regionFilter == filter
                                  ? null
                                  : filter;
                            });
                          },
                        ),
                        if (widget.visibleCountries.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _VisibleCountriesBar(
                            countries: widget.visibleCountries,
                            selectedCountry: widget.selectedCountry,
                            onSelected: widget.onCountrySelected,
                          ),
                        ],
                        if (!widget.isLoading &&
                            widget.errorMessage == null &&
                            widget.stations.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _DiscoverySections(
                            stations: widget.stations,
                            favoriteStations: widget.favoriteStations,
                            onStationTap: widget.onStationTap,
                          ),
                        ],
                        if (widget.isLoading) ...[
                          const SizedBox(height: 12),
                          _StatusChip(label: LocaleKeys.radio_map_loading.tr()),
                        ],
                      ],
                    ),
                  ),
                ),
                if (widget.errorMessage != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _MapMessage(
                      icon: Icons.wifi_off_rounded,
                      message: widget.errorMessage!,
                      actionLabel: LocaleKeys.radio_map_retry.tr(),
                      onAction: widget.onRetry,
                    ),
                  )
                else if (!widget.isLoading && filteredStations.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _MapMessage(
                      icon: Icons.radio_rounded,
                      message: widget.isSearching
                          ? LocaleKeys.no_radio_results.tr()
                          : LocaleKeys.radio_map_empty.tr(),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: filteredStations.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final station = filteredStations[index];
                        final isActive =
                            _stationPlaybackId(station) ==
                            widget.playingStationUuid;
                        return _MapStationTile(
                          station: station,
                          isActive: isActive,
                          isPlaying:
                              isActive &&
                              widget.playerState == PlayerState.playing,
                          isLoading:
                              widget.isLoadingPlayback &&
                              _stationPlaybackId(station) ==
                                  widget.playingStationUuid,
                          isFavorite: _isFavorite(station),
                          onTap: () => widget.onStationTap(station),
                          onFavoriteToggle: () =>
                              widget.onFavoriteToggle(station),
                          onAddToPlaylist: () =>
                              widget.onAddToPlaylist(station),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<RadioStation> get _filteredStations {
    var stations = widget.stations;

    final regionFilter = _regionFilter;
    if (regionFilter != null) {
      final codes = _regionCountryCodes[regionFilter] ?? const <String>{};
      stations = stations
          .where((station) => codes.contains(station.countryCode))
          .toList(growable: false);
    }

    final quickFilter = _quickFilter;
    if (quickFilter == null) return stations;

    switch (quickFilter) {
      case _QuickStationFilter.nearby:
        final codes = <String>{
          if (widget.selectedCountry != null) widget.selectedCountry!.code,
          for (final country in widget.visibleCountries) country.code,
        };
        if (codes.isEmpty) return stations;
        return stations
            .where((station) => codes.contains(station.countryCode))
            .toList(growable: false);
      case _QuickStationFilter.pop:
        return _stationsWithTag(stations, const ['pop']);
      case _QuickStationFilter.salsa:
        return _stationsWithTag(stations, const ['salsa']);
      case _QuickStationFilter.reggaeton:
        return _stationsWithTag(stations, const ['reggaeton', 'reggaet']);
      case _QuickStationFilter.news:
        return _stationsWithTag(stations, const ['news', 'noticias', 'talk']);
      case _QuickStationFilter.sports:
        return _stationsWithTag(stations, const ['sport', 'deportes']);
      case _QuickStationFilter.top:
        return _topStations(stations, limit: 50);
      case _QuickStationFilter.favorites:
        final favoriteIds = widget.favoriteStations
            .map((station) => station.stationUuid)
            .where((id) => id.isNotEmpty)
            .toSet();
        return stations
            .where((station) => favoriteIds.contains(station.stationUuid))
            .toList(growable: false);
    }
  }

  bool _isFavorite(RadioStation station) {
    return widget.favoriteStations.any(
      (favorite) => favorite.stationUuid == station.stationUuid,
    );
  }
}

List<RadioStation> _stationsWithTag(
  List<RadioStation> stations,
  List<String> needles,
) {
  return stations
      .where((station) {
        final tags = _normalizeCountryQuery(station.tags);
        final name = _normalizeCountryQuery(station.name);
        return needles.any(
          (needle) => tags.contains(needle) || name.contains(needle),
        );
      })
      .toList(growable: false);
}

List<RadioStation> _topStations(List<RadioStation> stations, {int limit = 8}) {
  final sorted = [...stations]
    ..sort((a, b) {
      final byClicks = b.clickCount.compareTo(a.clickCount);
      if (byClicks != 0) return byClicks;
      return b.votes.compareTo(a.votes);
    });
  return sorted.take(limit).toList(growable: false);
}

List<RadioStation> _qualityStations(List<RadioStation> stations) {
  final sorted = [...stations]
    ..sort((a, b) {
      final byBitrate = b.bitrate.compareTo(a.bitrate);
      if (byBitrate != 0) return byBitrate;
      return b.clickCount.compareTo(a.clickCount);
    });
  return sorted.take(8).toList(growable: false);
}

List<RadioStation> _discoveryStations(List<RadioStation> stations) {
  final sorted = [...stations.where((station) => station.clickCount > 0)]
    ..sort((a, b) {
      final byClicks = a.clickCount.compareTo(b.clickCount);
      if (byClicks != 0) return byClicks;
      return b.votes.compareTo(a.votes);
    });
  return sorted.take(8).toList(growable: false);
}

List<RadioStation> _recommendedStations(List<RadioStation> stations) {
  final sorted = [...stations]
    ..sort((a, b) {
      final aScore = (a.votes * 3) + a.clickCount + (a.bitrate ~/ 16);
      final bScore = (b.votes * 3) + b.clickCount + (b.bitrate ~/ 16);
      return bScore.compareTo(aScore);
    });
  return sorted.take(8).toList(growable: false);
}

String _stationDetails(RadioStation station, {bool includeTags = true}) {
  final origin = station.country.isNotEmpty
      ? station.country
      : station.countryCode;
  final primaryTag = station.tags
      .split(',')
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .take(1)
      .join();
  return [
    if (origin.isNotEmpty) origin,
    if (includeTags && primaryTag.isNotEmpty) primaryTag,
    if (station.codec.isNotEmpty) station.codec,
    if (station.bitrate > 0) '${station.bitrate} kbps',
  ].join(' · ');
}

class _QuickFiltersBar extends StatelessWidget {
  const _QuickFiltersBar({
    required this.selectedFilter,
    required this.onSelected,
  });

  final _QuickStationFilter? selectedFilter;
  final ValueChanged<_QuickStationFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _QuickStationFilter.values
            .map((filter) {
              final selected = selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: selected,
                  showCheckmark: false,
                  avatar: Icon(
                    _quickStationFilterIcons[filter],
                    size: 18,
                    color: selected ? colors.onPrimary : colors.primary,
                  ),
                  label: Text(_quickStationFilterLabel(filter)),
                  labelStyle: theme.textTheme.labelLarge?.copyWith(
                    color: selected ? colors.onPrimary : colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                  side: BorderSide(
                    color: selected ? colors.primary : colors.outlineVariant,
                  ),
                  backgroundColor: colors.surfaceContainerLowest.withValues(
                    alpha: 0.96,
                  ),
                  selectedColor: colors.primary,
                  onSelected: (_) => onSelected(filter),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _RegionFiltersBar extends StatelessWidget {
  const _RegionFiltersBar({
    required this.selectedFilter,
    required this.onSelected,
  });

  final _RegionFilter? selectedFilter;
  final ValueChanged<_RegionFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.explore_by_region.tr(),
          style: theme.textTheme.labelLarge?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _RegionFilter.values
                .map((filter) {
                  final selected = selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: selected,
                      showCheckmark: false,
                      avatar: Icon(
                        Icons.public_rounded,
                        size: 17,
                        color: selected ? colors.onSecondary : colors.secondary,
                      ),
                      label: Text(_regionFilterLabel(filter)),
                      labelStyle: theme.textTheme.labelMedium?.copyWith(
                        color: selected ? colors.onSecondary : colors.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                      side: BorderSide(
                        color: selected
                            ? colors.secondary
                            : colors.outlineVariant,
                      ),
                      backgroundColor: colors.surfaceContainerLowest.withValues(
                        alpha: 0.96,
                      ),
                      selectedColor: colors.secondary,
                      onSelected: (_) => onSelected(filter),
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _NowPlayingStationCard extends StatelessWidget {
  const _NowPlayingStationCard({
    required this.station,
    required this.isPlaying,
    required this.isLoading,
    required this.onTap,
  });

  final RadioStation station;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.primaryContainer.withValues(alpha: 0.52),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox.square(
                  dimension: 54,
                  child: station.artworkUrl.isEmpty
                      ? _RadioArtwork(colors: colors)
                      : OptimizedNetworkImage(
                          url: station.artworkUrl,
                          displaySize: 54,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _RadioArtwork(colors: colors),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sonando ahora',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      station.name.isEmpty
                          ? LocaleKeys.radio.tr()
                          : station.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _stationDetails(station),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StationActionsMenu(station: station),
              IconButton.filled(
                onPressed: onTap,
                icon: isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverySections extends StatelessWidget {
  const _DiscoverySections({
    required this.stations,
    required this.favoriteStations,
    required this.onStationTap,
  });

  final List<RadioStation> stations;
  final List<RadioStation> favoriteStations;
  final ValueChanged<RadioStation> onStationTap;

  @override
  Widget build(BuildContext context) {
    final sections = [
      (LocaleKeys.section_most_listened.tr(), _topStations(stations)),
      (LocaleKeys.section_new_stations.tr(), _discoveryStations(stations)),
      (LocaleKeys.section_best_quality.tr(), _qualityStations(stations)),
      (
        LocaleKeys.section_recommended_for_you.tr(),
        _recommendedStations(stations),
      ),
      if (favoriteStations.isNotEmpty)
        (
          LocaleKeys.section_your_favorites.tr(),
          favoriteStations.take(8).toList(),
        ),
    ].where((section) => section.$2.isNotEmpty).toList(growable: false);

    if (sections.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _DiscoveryStationRail(
            title: sections[i].$1,
            stations: sections[i].$2,
            onStationTap: onStationTap,
          ),
        ],
      ],
    );
  }
}

class _DiscoveryStationRail extends StatelessWidget {
  const _DiscoveryStationRail({
    required this.title,
    required this.stations,
    required this.onStationTap,
  });

  final String title;
  final List<RadioStation> stations;
  final ValueChanged<RadioStation> onStationTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${stations.length}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: stations.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final station = stations[index];
              return _DiscoveryStationCard(
                station: station,
                onTap: () => onStationTap(station),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DiscoveryStationCard extends StatelessWidget {
  const _DiscoveryStationCard({required this.station, required this.onTap});

  final RadioStation station;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SizedBox(
      width: 182,
      child: Material(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox.square(
                        dimension: 42,
                        child: station.artworkUrl.isEmpty
                            ? _RadioArtwork(colors: colors)
                            : OptimizedNetworkImage(
                                url: station.artworkUrl,
                                displaySize: 42,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _RadioArtwork(colors: colors),
                              ),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.play_circle_fill_rounded, color: colors.primary),
                  ],
                ),
                const Spacer(),
                Text(
                  station.name.isEmpty ? LocaleKeys.radio.tr() : station.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _stationDetails(station),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
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

class _MapStationTile extends StatelessWidget {
  const _MapStationTile({
    required this.station,
    required this.isActive,
    required this.isPlaying,
    required this.isLoading,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteToggle,
    required this.onAddToPlaylist,
  });

  final RadioStation station;
  final bool isActive;
  final bool isPlaying;
  final bool isLoading;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onAddToPlaylist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final extras = theme.extension<FlowThemeExtras>();
    final details = _stationDetails(station);

    return Material(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive
                  ? colors.primary
                  : extras?.subtleStroke ?? colors.outlineVariant,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox.square(
                  dimension: 52,
                  child: station.artworkUrl.isEmpty
                      ? _RadioArtwork(colors: colors)
                      : OptimizedNetworkImage(
                          url: station.artworkUrl,
                          displaySize: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _RadioArtwork(colors: colors),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            station.name.isEmpty
                                ? LocaleKeys.radio.tr()
                                : station.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _LiveBadge(isActive: isPlaying),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(_countryFlagEmoji(station.countryCode)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            details,
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
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        _TinyMetaChip(
                          icon: Icons.podcasts_rounded,
                          label: isPlaying
                              ? LocaleKeys.playing.tr()
                              : 'En vivo',
                        ),
                        if (station.votes > 0) ...[
                          const SizedBox(width: 6),
                          _TinyMetaChip(
                            icon: Icons.thumb_up_alt_rounded,
                            label: '${station.votes}',
                          ),
                        ],
                        if (station.clickCount > 0) ...[
                          const SizedBox(width: 6),
                          _TinyMetaChip(
                            icon: Icons.trending_up_rounded,
                            label: '${station.clickCount}',
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: onFavoriteToggle,
                icon: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
                tooltip: isFavorite
                    ? LocaleKeys.remove_from_favorites.tr()
                    : LocaleKeys.add_to_favorites.tr(),
                color: isFavorite ? colors.primary : colors.onSurfaceVariant,
              ),
              IconButton(
                onPressed: onAddToPlaylist,
                icon: const Icon(Icons.playlist_add_rounded),
                tooltip: LocaleKeys.add_to_radio_playlist.tr(),
                color: colors.onSurfaceVariant,
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
                tooltip: isPlaying
                    ? LocaleKeys.pause.tr()
                    : LocaleKeys.play.tr(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isActive ? colors.primary : colors.surfaceContainerHighest)
            .withValues(alpha: isActive ? 0.18 : 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? LocaleKeys.playing.tr() : 'En vivo',
        style: theme.textTheme.labelSmall?.copyWith(
          color: isActive ? colors.primary : colors.onSurfaceVariant,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TinyMetaChip extends StatelessWidget {
  const _TinyMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: colors.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

class _MapMessage extends StatelessWidget {
  const _MapMessage({
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
          Icon(icon, size: 42, color: colors.primary),
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
