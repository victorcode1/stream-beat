import 'dart:math';

import 'package:flow_music/features/autoplay/data/mix_playlist_repository.dart';
import 'package:flow_music/features/home/data/apple_top_charts_service.dart';
import 'package:flow_music/features/home/data/location_service.dart';
import 'package:flow_music/features/home/data/youtube_music_charts.dart';
import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/features/search/data/repositories/song_title_normalizer.dart';
import 'package:flow_music/features/search/data/repositories/youtube_suggestions_repository.dart';
import 'package:flutter/foundation.dart';

typedef HomeSearchLoader =
    Future<List<YouTubeSearchSuggestion>> Function(
      String query, {
      String source,
    });
typedef HomeMixLoader =
    Future<MixPlaylistPage> Function(YouTubeSearchSuggestion seed);
typedef HomeChartLoader =
    Future<List<YouTubeSearchSuggestion>> Function(String countryCode);

/// Resultado de `HomeSuggestionsRepository.load`.
class HomeSuggestionsResult {
  const HomeSuggestionsResult({
    required this.suggestions,
    required this.countryName,
    this.chart = const [],
    this.forYou = const [],
  });

  /// Lista de canciones sugeridas para mostrar.
  final List<YouTubeSearchSuggestion> suggestions;

  /// Nombre legible del pais resuelto (`Colombia`, `United States`...).
  /// `null` cuando no se pudo resolver y se usaron fallback genericos.
  final String? countryName;

  /// Exitos del pais en su orden (#1 primero), para la lista numerada.
  final List<YouTubeSearchSuggestion> chart;

  /// Radio de lo ultimo que se escucho, para «Para ti».
  final List<YouTubeSearchSuggestion> forYou;
}

/// Fuente de sugerencias para la pantalla inicial.
///
/// Fuente principal: el top real de canciones del pais via el feed gratuito de
/// Apple Music (`AppleTopChartsService`). Como la app reproduce desde YouTube,
/// cada top se resuelve a su `videoId` buscandolo en YouTube, conservando el
/// titulo, el artista y la portada cuadrada de Apple.
///
/// La tanda se mezcla con la parte "para ti": la radio (mix) de lo ultimo que
/// escucho el usuario. Y en cada refresco cambia — se corren las semillas del
/// historial y la ventana del top del pais — para que el home no muestre
/// siempre lo mismo.
///
/// Si Apple no responde (o ninguna cancion resuelve), cae a una busqueda
/// generica por pais en YouTube para que la pantalla nunca quede vacia.
class HomeSuggestionsRepository {
  HomeSuggestionsRepository({
    LocationService? locationService,
    AppleTopChartsService? appleService,
    HomeSearchLoader? searchLoader,
    HomeMixLoader? mixLoader,
    HomeChartLoader? chartLoader,
    String? Function()? localeCountry,
  }) : _locationService = locationService ?? const LocationService(),
       _appleService = appleService ?? const AppleTopChartsService(),
       _searchLoader = searchLoader ?? fetchYouTubeSearchSuggestions,
       _mixLoader = mixLoader ?? fetchMixPlaylist,
       _chartLoader = chartLoader ?? fetchYouTubeMusicTrending,
       _localeCountry = localeCountry ?? _deviceCountry;

  final LocationService _locationService;
  final AppleTopChartsService _appleService;
  final HomeSearchLoader _searchLoader;
  final HomeMixLoader _mixLoader;
  final HomeChartLoader _chartLoader;
  final String? Function() _localeCountry;

  /// Pais de la configuracion del telefono, para cuando no hay ubicacion.
  static String? _deviceCountry() =>
      PlatformDispatcher.instance.locale.countryCode;

  /// Cuantas canciones del top intentamos resolver contra YouTube y el tamano
  /// de cada lote concurrente (para no saturar a YouTube).
  static const int _maxToResolve = 16;
  static const int _resolveChunkSize = 4;

  /// Cuantas canciones del historial siembran la parte "para ti" y cuantas
  /// pistas se toman de la radio de cada una.
  static const int _maxPersonalSeeds = 2;
  static const int _tracksPerSeed = 4;

  /// Cuanto se corre la ventana del top del pais en cada refresco.
  static const int _chartRotationStep = 5;

  /// Queries por pais (ISO 3166-1 alpha-2). Si el pais no esta listado, se
  /// arma una query generica con el nombre/codigo.
  static const Map<String, List<String>> _countryQueries = {
    'CO': ['Musica popular Colombia', 'Top hits Colombia'],
    'MX': ['Musica popular Mexico', 'Top hits Mexico'],
    'AR': ['Musica popular Argentina', 'Top hits Argentina'],
    'CL': ['Musica popular Chile', 'Top hits Chile'],
    'PE': ['Musica popular Peru', 'Top hits Peru'],
    'ES': ['Musica popular Espana', 'Top hits Espana'],
    'US': ['Top hits USA', 'Billboard top songs'],
    'BR': ['Musica popular Brasil', 'Top hits Brasil'],
    'GB': ['UK top hits', 'Popular music UK'],
    'FR': ['Musique populaire France', 'Top hits France'],
    'DE': ['Top hits Deutschland', 'Beliebte musik Deutschland'],
    'IT': ['Musica popolare Italia', 'Top hits Italia'],
    'JP': ['Japan top hits', 'J-pop popular'],
    'KR': ['K-pop top hits', 'Korea popular songs'],
    'CA': ['Canada top hits', 'Popular music Canada'],
  };

  /// Queries de respaldo cuando no hay ubicacion.
  static final List<String> _fallbackQueries = [
    'Top hits ${DateTime.now().year}',
    'Greatest music hits',
    'Popular songs ${DateTime.now().year}',
    'Top music playlist',
    'Musica popular ${DateTime.now().year}',
    'Best songs of all time',
    'Trending music now',
    'Hits of ${DateTime.now().year}',
    'Top charts ${DateTime.now().year}',
    'Best of ${DateTime.now().year}',
    'Most popular ${DateTime.now().year}',
    'Mix of top hits',
    'Playlist top hits ${DateTime.now().year}',
  ];

  /// [rotation] sube en cada refresco: es lo que hace que la tanda cambie.
  /// [recentlyPlayed] son las ultimas canciones escuchadas, mas recientes
  /// primero.
  Future<HomeSuggestionsResult> load({
    int rotation = 0,
    List<YouTubeSearchSuggestion> recentlyPlayed = const [],
  }) async {
    // La parte personal no depende del pais: arranca ya, en paralelo.
    final personalFuture = _personalPicks(
      recentlyPlayed: recentlyPlayed,
      rotation: rotation,
    );
    final country = await _locationService.resolveCountry();
    final chartFuture = _countryChart(country);
    final personal = await personalFuture;
    final chart = await chartFuture;

    final merged = _merge([
      personal,
      _rotated(chart, rotation * _chartRotationStep),
    ]);
    if (merged.isNotEmpty) {
      return HomeSuggestionsResult(
        suggestions: merged,
        countryName: country.countryName,
        chart: chart,
        forYou: personal,
      );
    }

    // Respaldo: busqueda generica por pais en YouTube.
    final query = _pickQuery(country, rotation);
    final suggestions = await _searchLoader(
      query,
      source: 'HomeSuggestionsRepository',
    );

    return HomeSuggestionsResult(
      suggestions: suggestions,
      countryName: country.countryName,
    );
  }

  /// Exitos del pais: primero YouTube Music (dos llamadas, ya con videos); si
  /// falla, el top de Apple resuelto contra YouTube como antes.
  Future<List<YouTubeSearchSuggestion>> _countryChart(
    ResolvedCountry country,
  ) async {
    final code = country.countryCode ?? _localeCountry() ?? 'ZZ';
    try {
      final chart = await _chartLoader(code);
      if (chart.isNotEmpty) return chart;
    } catch (error) {
      debugPrint('YouTube Music chart for $code failed: $error');
    }

    final topSongs = await _appleService.fetchTopSongs(
      countryCode: country.countryCode,
    );
    if (topSongs.isEmpty) return const [];
    return _resolveTopSongs(topSongs);
  }

  /// Parte "para ti": la radio de las ultimas canciones escuchadas. Se rota que
  /// semillas se usan para que dos refrescos seguidos no den lo mismo.
  Future<List<YouTubeSearchSuggestion>> _personalPicks({
    required List<YouTubeSearchSuggestion> recentlyPlayed,
    required int rotation,
  }) async {
    final seeds = <YouTubeSearchSuggestion>[];
    for (var i = 0; i < recentlyPlayed.length; i++) {
      if (seeds.length >= _maxPersonalSeeds) break;
      final seed = recentlyPlayed[(rotation + i) % recentlyPlayed.length];
      if (seed.videoId.isEmpty) continue;
      if (seeds.any((picked) => picked.videoId == seed.videoId)) continue;
      seeds.add(seed);
    }
    if (seeds.isEmpty) return const [];

    final pages = await Future.wait(seeds.map(_safeMix));
    return [for (final page in pages) ...page.tracks.take(_tracksPerSeed)];
  }

  Future<MixPlaylistPage> _safeMix(YouTubeSearchSuggestion seed) async {
    try {
      return await _mixLoader(seed);
    } catch (error) {
      debugPrint('Home mix for "${seed.displayText}" failed: $error');
      return MixPlaylistPage.empty;
    }
  }

  /// Intercala las fuentes por turnos (una personal, una del top...) y descarta
  /// repetidos por id y por titulo+artista.
  List<YouTubeSearchSuggestion> _merge(
    List<List<YouTubeSearchSuggestion>> sources,
  ) {
    final merged = <YouTubeSearchSuggestion>[];
    final seenIds = <String>{};
    final seenKeys = <String>{};
    final longest = sources.fold<int>(
      0,
      (longest, source) => source.length > longest ? source.length : longest,
    );

    for (var index = 0; index < longest; index++) {
      for (final source in sources) {
        if (index >= source.length) continue;
        final item = source[index];
        if (item.videoId.isEmpty || !seenIds.add(item.videoId)) continue;
        final key = songDedupKey(
          title: item.displayText,
          artist: item.channelTitle,
        );
        if (key.isNotEmpty && !seenKeys.add(key)) continue;
        merged.add(item);
      }
    }
    return merged;
  }

  /// Corre la lista [offset] posiciones sin perder elementos, para mostrar otra
  /// parte del top en cada refresco.
  List<T> _rotated<T>(List<T> items, int offset) {
    if (items.length < 2) return items;
    final shift = offset % items.length;
    if (shift == 0) return items;
    return [...items.sublist(shift), ...items.sublist(0, shift)];
  }

  /// Resuelve los tops de Apple contra YouTube en lotes concurrentes,
  /// conservando titulo/artista/portada de Apple y descartando duplicados.
  Future<List<YouTubeSearchSuggestion>> _resolveTopSongs(
    List<AppleTopSong> songs,
  ) async {
    final pending = songs.take(_maxToResolve).toList(growable: false);
    final resolved = <YouTubeSearchSuggestion>[];
    final seen = <String>{};

    for (var i = 0; i < pending.length; i += _resolveChunkSize) {
      final chunk = pending.sublist(
        i,
        min(i + _resolveChunkSize, pending.length),
      );
      final batch = await Future.wait(chunk.map(_resolveSong));
      for (final suggestion in batch) {
        if (suggestion == null) continue;
        if (!seen.add(suggestion.videoId)) continue;
        resolved.add(suggestion);
      }
    }
    return resolved;
  }

  Future<YouTubeSearchSuggestion?> _resolveSong(AppleTopSong song) async {
    final query = song.artist.isEmpty
        ? song.name
        : '${song.artist} ${song.name}';
    try {
      final results = await _searchLoader(query, source: 'AppleTopChart');
      if (results.isEmpty) return null;
      final match = results.first;
      if (match.videoId.isEmpty) return null;
      return YouTubeSearchSuggestion(
        videoId: match.videoId,
        displayText: song.name,
        channelTitle: song.artist,
        thumbnailUrl: song.artworkUrl.isNotEmpty
            ? song.artworkUrl
            : match.thumbnailUrl,
        duration: match.duration,
      );
    } catch (error) {
      debugPrint('Resolve top song failed for "$query": $error');
      return null;
    }
  }

  /// La query tambien rota, asi el respaldo no repite siempre la misma busqueda.
  String _pickQuery(ResolvedCountry country, int rotation) {
    final code = country.countryCode;
    if (code != null && _countryQueries.containsKey(code)) {
      final list = _countryQueries[code]!;
      return list[rotation % list.length];
    }
    if (code != null && country.countryName != null) {
      return 'Top music ${country.countryName}';
    }
    return _fallbackQueries[rotation % _fallbackQueries.length];
  }
}
