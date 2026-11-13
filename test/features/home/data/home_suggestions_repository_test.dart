import 'package:flow_music/features/autoplay/data/mix_playlist_repository.dart';
import 'package:flow_music/features/home/data/apple_top_charts_service.dart';
import 'package:flow_music/features/home/data/home_suggestions_repository.dart';
import 'package:flow_music/features/home/data/location_service.dart';
import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLocationService extends LocationService {
  const _FakeLocationService();

  @override
  Future<ResolvedCountry> resolveCountry({
    Duration timeLimit = const Duration(seconds: 8),
  }) async => const ResolvedCountry(countryCode: 'CO', countryName: 'Colombia');
}

class _FakeChartsService extends AppleTopChartsService {
  const _FakeChartsService(this.songs);

  final List<AppleTopSong> songs;

  @override
  Future<List<AppleTopSong>> fetchTopSongs({
    String? countryCode,
    int limit = 20,
  }) async => songs;
}

/// Cada cancion del top resuelve a un videoId derivado de su nombre.
Future<List<YouTubeSearchSuggestion>> _fakeSearch(
  String query, {
  String source = 'test',
}) async {
  final slug = query.split(' ').last;
  return [
    YouTubeSearchSuggestion(
      videoId: 'chart-$slug',
      displayText: query,
      channelTitle: 'Chart artist',
      thumbnailUrl: '',
    ),
  ];
}

List<AppleTopSong> _chartSongs(int count) => List.generate(
  count,
  (index) => AppleTopSong(
    name: 'top$index',
    artist: 'Chart artist',
    artworkUrl: 'https://example.com/$index.jpg',
  ),
  growable: false,
);

HomeSuggestionsRepository _repository({
  int chartSize = 10,
  HomeMixLoader? mixLoader,
  HomeChartLoader? chartLoader,
}) {
  return HomeSuggestionsRepository(
    locationService: const _FakeLocationService(),
    appleService: _FakeChartsService(_chartSongs(chartSize)),
    searchLoader: _fakeSearch,
    mixLoader: mixLoader ?? (_) async => MixPlaylistPage.empty,
    // Por defecto YouTube Music no responde, asi se prueba el respaldo de
    // Apple; las pruebas del camino nuevo pasan su propia lista.
    chartLoader: chartLoader ?? (_) async => const [],
  );
}

List<YouTubeSearchSuggestion> _musicChart(int count) => List.generate(
  count,
  (index) => YouTubeSearchSuggestion(
    videoId: 'ytm-$index',
    displayText: 'Hit $index',
    channelTitle: 'Artist $index',
    thumbnailUrl: '',
  ),
  growable: false,
);

void main() {
  test('each refresh shows a different slice of the country chart', () async {
    final repository = _repository();

    final first = await repository.load();
    final second = await repository.load(rotation: 1);
    final third = await repository.load(rotation: 2);

    // La ventana se corre 5 posiciones por refresco sobre un top de 10.
    expect(first.suggestions.first.videoId, 'chart-top0');
    expect(second.suggestions.first.videoId, 'chart-top5');
    expect(third.suggestions.first.videoId, 'chart-top0');
    // Sin perder canciones: solo cambia por donde empieza.
    expect(
      second.suggestions.map((song) => song.videoId).toSet(),
      first.suggestions.map((song) => song.videoId).toSet(),
    );
    expect(first.countryName, 'Colombia');
  });

  test('the radio of recently played songs is mixed into the batch', () async {
    final seenSeeds = <String>[];
    final repository = _repository(
      mixLoader: (seed) async {
        seenSeeds.add(seed.videoId);
        return MixPlaylistPage(
          playlistId: mixPlaylistIdFor(seed.videoId),
          tracks: List.generate(
            6,
            (index) => YouTubeSearchSuggestion(
              videoId: '${seed.videoId}-mix$index',
              displayText: 'Mix of ${seed.videoId} $index',
              channelTitle: 'Mix artist',
              thumbnailUrl: '',
            ),
            growable: false,
          ),
        );
      },
    );

    const recentlyPlayed = [
      YouTubeSearchSuggestion(
        videoId: 'played-one',
        displayText: 'Played one',
        channelTitle: 'Artist',
        thumbnailUrl: '',
      ),
      YouTubeSearchSuggestion(
        videoId: 'played-two',
        displayText: 'Played two',
        channelTitle: 'Artist',
        thumbnailUrl: '',
      ),
      YouTubeSearchSuggestion(
        videoId: 'played-three',
        displayText: 'Played three',
        channelTitle: 'Artist',
        thumbnailUrl: '',
      ),
    ];

    final batch = await repository.load(recentlyPlayed: recentlyPlayed);
    final ids = batch.suggestions.map((song) => song.videoId).toList();

    // Dos semillas por tanda, y se intercala una personal con una del top.
    expect(seenSeeds, ['played-one', 'played-two']);
    expect(ids.first, 'played-one-mix0');
    expect(ids[1], 'chart-top0');
    expect(ids.where((id) => id.contains('-mix')), hasLength(8));

    // Al refrescar cambian las semillas: la tanda no repite lo de antes.
    seenSeeds.clear();
    await repository.load(rotation: 1, recentlyPlayed: recentlyPlayed);
    expect(seenSeeds, ['played-two', 'played-three']);
  });

  test('a song present in both sources is only listed once', () async {
    final repository = _repository(
      mixLoader: (seed) async => const MixPlaylistPage(
        playlistId: 'RDseed',
        tracks: [
          // El mismo videoId que resolvera el top: no debe salir dos veces.
          YouTubeSearchSuggestion(
            videoId: 'chart-top0',
            displayText: 'top0',
            channelTitle: 'Chart artist',
            thumbnailUrl: '',
          ),
        ],
      ),
    );

    final batch = await repository.load(
      recentlyPlayed: const [
        YouTubeSearchSuggestion(
          videoId: 'played-one',
          displayText: 'Played one',
          channelTitle: 'Artist',
          thumbnailUrl: '',
        ),
      ],
    );

    final ids = batch.suggestions.map((song) => song.videoId).toList();
    expect(ids.where((id) => id == 'chart-top0'), hasLength(1));
  });

  test('the YouTube Music chart is used first, in its own order', () async {
    final requestedCountries = <String>[];
    final repository = _repository(
      chartLoader: (country) async {
        requestedCountries.add(country);
        return _musicChart(5);
      },
    );

    final result = await repository.load();

    expect(requestedCountries, ['CO']);
    expect(result.chart.map((song) => song.videoId), [
      'ytm-0',
      'ytm-1',
      'ytm-2',
      'ytm-3',
      'ytm-4',
    ]);
    expect(result.suggestions.first.videoId, 'ytm-0');
    // Con YouTube Music respondiendo no se busca cancion por cancion.
    expect(
      result.suggestions.any((song) => song.videoId.startsWith('chart-')),
      isFalse,
    );
  });

  test('the Apple chart is the fallback when YouTube Music fails', () async {
    final repository = _repository(
      chartLoader: (_) async => throw Exception('sin red'),
    );

    final result = await repository.load();

    expect(result.chart.first.videoId, 'chart-top0');
  });
}
