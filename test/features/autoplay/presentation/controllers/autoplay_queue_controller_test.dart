import 'dart:async';

import 'package:flow_music/features/autoplay/data/mix_playlist_repository.dart';
import 'package:flow_music/features/autoplay/data/resolved_audio.dart';
import 'package:flow_music/features/autoplay/presentation/controllers/autoplay_queue_controller.dart';
import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  test(
    'a pending next from an old session cannot skip the new selection',
    () async {
      final mix = Completer<MixPlaylistPage>();
      final container = ProviderContainer(
        overrides: [
          autoplayMixLoaderProvider.overrideWithValue((_) => mix.future),
          autoplayAudioResolverProvider.overrideWithValue((_) async => null),
        ],
      );
      addTearDown(container.dispose);
      final queue = container.read(autoplayQueueControllerProvider.notifier);
      const a = YouTubeSearchSuggestion(
        videoId: 'a',
        displayText: 'A',
        channelTitle: '',
        thumbnailUrl: '',
      );
      const b = YouTubeSearchSuggestion(
        videoId: 'b',
        displayText: 'B',
        channelTitle: '',
        thumbnailUrl: '',
      );
      const c = YouTubeSearchSuggestion(
        videoId: 'c',
        displayText: 'C',
        channelTitle: '',
        thumbnailUrl: '',
      );
      queue.enqueue(const [a], 0);
      final oldNext = queue.playNext();
      queue.enqueue(const [b, c], 0, collection: true);
      mix.complete(MixPlaylistPage.empty);
      expect(await oldNext, isNull);
      expect(
        container.read(autoplayQueueControllerProvider).current?.videoId,
        'b',
      );
    },
  );

  test(
    'stale resolution cannot overwrite the same song in a newer session',
    () async {
      final requests = <Completer<ResolvedAudio?>>[];
      final container = ProviderContainer(
        overrides: [
          autoplayAudioResolverProvider.overrideWithValue((_) {
            final request = Completer<ResolvedAudio?>();
            requests.add(request);
            return request.future;
          }),
        ],
      );
      addTearDown(container.dispose);
      final queue = container.read(autoplayQueueControllerProvider.notifier);
      const a = YouTubeSearchSuggestion(
        videoId: 'a',
        displayText: 'A',
        channelTitle: '',
        thumbnailUrl: '',
      );
      const b = YouTubeSearchSuggestion(
        videoId: 'b',
        displayText: 'B',
        channelTitle: '',
        thumbnailUrl: '',
      );
      queue.enqueue(const [a, b], 0, collection: true);
      queue.enqueue(const [a, b], 0, collection: true);
      expect(requests, hasLength(2));
      requests.last.complete(
        const ResolvedAudio(
          suggestion: b,
          audioUrl: 'https://new.example/audio',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      requests.first.complete(
        const ResolvedAudio(
          suggestion: b,
          audioUrl: 'https://old.example/audio',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(autoplayQueueControllerProvider).resolved['b']?.audioUrl,
        'https://new.example/audio',
      );
    },
  );

  test(
    'collection stays ordered, wraps and never fetches recommendations',
    () async {
      var recommendations = 0;
      final container = ProviderContainer(
        overrides: [
          autoplayMixLoaderProvider.overrideWithValue((_) async {
            recommendations++;
            return MixPlaylistPage.empty;
          }),
          autoplayRelatedLoaderProvider.overrideWithValue((_) async {
            recommendations++;
            return const [];
          }),
          autoplaySuggestionLoaderProvider.overrideWithValue((_) async {
            recommendations++;
            return const [];
          }),
          autoplayAudioResolverProvider.overrideWithValue((_) async => null),
        ],
      );
      addTearDown(container.dispose);
      final queue = container.read(autoplayQueueControllerProvider.notifier);
      final songs = List.generate(
        3,
        (i) => YouTubeSearchSuggestion(
          videoId: 'favorite-$i',
          displayText: 'Same title',
          channelTitle: 'Artist',
          thumbnailUrl: '',
        ),
      );
      queue.enqueue(songs, 1, collection: true);
      expect((await queue.playNext())?.suggestion.videoId, 'favorite-2');
      expect((await queue.playNext())?.suggestion.videoId, 'favorite-0');
      expect(queue.playPrevious()?.suggestion.videoId, 'favorite-2');
      expect((await queue.playNext())?.suggestion.videoId, 'favorite-0');
      expect((await queue.playNext())?.suggestion.videoId, 'favorite-1');
      await queue.loadMoreUpcoming();
      expect(
        container.read(autoplayQueueControllerProvider).canLoadMore,
        isFalse,
      );
      expect(recommendations, 0);
    },
  );

  test(
    'a single favorite repeats and a new search resets collection mode',
    () async {
      final container = ProviderContainer(
        overrides: [
          autoplayMixLoaderProvider.overrideWithValue(
            (_) async => MixPlaylistPage.empty,
          ),
          autoplayRelatedLoaderProvider.overrideWithValue(
            (_) async => const [],
          ),
          autoplaySuggestionLoaderProvider.overrideWithValue(
            (_) async => const [],
          ),
          autoplayAudioResolverProvider.overrideWithValue((_) async => null),
        ],
      );
      addTearDown(container.dispose);
      final queue = container.read(autoplayQueueControllerProvider.notifier);
      const song = YouTubeSearchSuggestion(
        videoId: 'only',
        displayText: 'Only',
        channelTitle: '',
        thumbnailUrl: '',
      );
      queue.enqueue(const [song], 0, collection: true);
      expect((await queue.playNext())?.suggestion.videoId, 'only');
      expect(queue.playPrevious()?.suggestion.videoId, 'only');
      queue.enqueue(const [song], 0);
      expect(
        container.read(autoplayQueueControllerProvider).isCollection,
        isFalse,
      );
    },
  );

  test(
    'playNext waits for a background refill when the queue is empty',
    () async {
      final loaderStarted = Completer<void>();
      final loaderResult = Completer<List<YouTubeSearchSuggestion>>();
      final queries = <String>[];
      final container = ProviderContainer(
        overrides: [
          autoplaySuggestionLoaderProvider.overrideWithValue((query) {
            queries.add(query);
            if (!loaderStarted.isCompleted) loaderStarted.complete();
            return loaderResult.future;
          }),
          autoplayRelatedLoaderProvider.overrideWithValue(
            (_) async => const [],
          ),
          autoplayMixLoaderProvider.overrideWithValue(
            (_) async => MixPlaylistPage.empty,
          ),
          autoplayMixPageLoaderProvider.overrideWithValue(
            (_, _) async => MixPlaylistPage.empty,
          ),
          autoplayAudioResolverProvider.overrideWithValue((_) async => null),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(autoplayQueueControllerProvider.notifier);
      const current = YouTubeSearchSuggestion(
        videoId: 'current-song',
        displayText: 'Current song',
        channelTitle: 'Current artist',
        thumbnailUrl: '',
      );
      const next = YouTubeSearchSuggestion(
        videoId: 'next-song',
        displayText: 'Next song',
        channelTitle: 'Next artist',
        thumbnailUrl: '',
      );

      notifier.enqueue(const [current], 0);
      await loaderStarted.future;

      final loadingState = container.read(autoplayQueueControllerProvider);
      expect(loadingState.hasNext, isTrue);
      expect(loadingState.isLoadingMore, isTrue);

      final nextTrackFuture = notifier.playNext();
      loaderResult.complete(const [current, next, next]);
      final nextTrack = await nextTrackFuture;

      expect(nextTrack?.suggestion.videoId, next.videoId);
      expect(
        container.read(autoplayQueueControllerProvider).current?.videoId,
        next.videoId,
      );
      expect(queries.first, contains('Current song'));
    },
  );

  test('refills before the remaining songs are exhausted', () async {
    final loaderStarted = Completer<void>();
    final loaderResult = Completer<List<YouTubeSearchSuggestion>>();
    final refillCompleted = Completer<void>();
    final container = ProviderContainer(
      overrides: [
        autoplaySuggestionLoaderProvider.overrideWithValue((query) {
          if (!loaderStarted.isCompleted) loaderStarted.complete();
          return loaderResult.future;
        }),
        autoplayRelatedLoaderProvider.overrideWithValue((_) async => const []),
        autoplayMixLoaderProvider.overrideWithValue(
          (_) async => MixPlaylistPage.empty,
        ),
        autoplayMixPageLoaderProvider.overrideWithValue(
          (_, _) async => MixPlaylistPage.empty,
        ),
        autoplayAudioResolverProvider.overrideWithValue((_) async => null),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(autoplayQueueControllerProvider, (
      previous,
      next,
    ) {
      if (!next.isLoadingMore &&
          next.upcoming.any((song) => song.videoId == 'refilled-song') &&
          !refillCompleted.isCompleted) {
        refillCompleted.complete();
      }
    });
    addTearDown(subscription.close);

    final notifier = container.read(autoplayQueueControllerProvider.notifier);
    const current = YouTubeSearchSuggestion(
      videoId: 'current-song',
      displayText: 'Current song',
      channelTitle: 'Current artist',
      thumbnailUrl: '',
    );
    const queuedOne = YouTubeSearchSuggestion(
      videoId: 'queued-one',
      displayText: 'Queued one',
      channelTitle: 'Artist',
      thumbnailUrl: '',
    );
    const queuedTwo = YouTubeSearchSuggestion(
      videoId: 'queued-two',
      displayText: 'Queued two',
      channelTitle: 'Artist',
      thumbnailUrl: '',
    );
    const refilled = YouTubeSearchSuggestion(
      videoId: 'refilled-song',
      displayText: 'Refilled song',
      channelTitle: 'Another artist',
      thumbnailUrl: '',
    );

    notifier.enqueue(const [current, queuedOne, queuedTwo], 0);
    await loaderStarted.future;
    expect(
      container.read(autoplayQueueControllerProvider).upcoming,
      hasLength(2),
    );

    loaderResult.complete(const [current, queuedOne, refilled]);
    await refillCompleted.future;

    final upcoming = container.read(autoplayQueueControllerProvider).upcoming;
    expect(upcoming.map((song) => song.videoId), [
      queuedOne.videoId,
      queuedTwo.videoId,
      refilled.videoId,
    ]);
  });

  test(
    'refills from the related pool of the tapped song, without repeats',
    () async {
      final seeds = <String>[];
      final refillSettled = Completer<void>();

      const current = YouTubeSearchSuggestion(
        videoId: 'current-song',
        displayText: 'Bad Bunny - Titi Me Pregunto (Video Oficial)',
        channelTitle: 'Bad Bunny',
        thumbnailUrl: '',
      );
      // Mismo tema, otro upload: no debe volver a entrar a la cola.
      const reupload = YouTubeSearchSuggestion(
        videoId: 'current-song-lyrics',
        displayText: 'Titi Me Pregunto (Letra)',
        channelTitle: 'Bad Bunny - Topic',
        thumbnailUrl: '',
      );
      const relatedOne = YouTubeSearchSuggestion(
        videoId: 'related-one',
        displayText: 'Moscow Mule',
        channelTitle: 'Bad Bunny',
        thumbnailUrl: '',
      );
      const relatedTwo = YouTubeSearchSuggestion(
        videoId: 'related-two',
        displayText: 'Ojitos Lindos',
        channelTitle: 'Bad Bunny',
        thumbnailUrl: '',
      );

      final container = ProviderContainer(
        overrides: [
          autoplaySuggestionLoaderProvider.overrideWithValue(
            (_) async => const [],
          ),
          autoplayRelatedLoaderProvider.overrideWithValue((seed) async {
            seeds.add(seed.videoId);
            // El mismo pozo en cada llamada: solo lo realmente nuevo entra.
            return const [reupload, relatedOne, relatedTwo];
          }),
          autoplayMixLoaderProvider.overrideWithValue(
            (_) async => MixPlaylistPage.empty,
          ),
          autoplayMixPageLoaderProvider.overrideWithValue(
            (_, _) async => MixPlaylistPage.empty,
          ),
          autoplayAudioResolverProvider.overrideWithValue((_) async => null),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(autoplayQueueControllerProvider, (
        previous,
        next,
      ) {
        if ((previous?.isLoadingMore ?? false) &&
            !next.isLoadingMore &&
            !refillSettled.isCompleted) {
          refillSettled.complete();
        }
      });
      addTearDown(subscription.close);

      container.read(autoplayQueueControllerProvider.notifier).enqueue(const [
        current,
      ], 0);
      await refillSettled.future;

      final queue = container.read(autoplayQueueControllerProvider);
      expect(seeds.first, current.videoId);
      expect(queue.upcoming.map((song) => song.videoId), [
        relatedOne.videoId,
        relatedTwo.videoId,
      ]);
    },
  );

  test(
    'prefetches the head of the queue with a bounded pool of workers',
    () async {
      final started = <String>[];
      final pending = <String, Completer<ResolvedAudio?>>{};
      final mixTracks = List.generate(
        11,
        (index) => YouTubeSearchSuggestion(
          videoId: 'song-${index + 1}',
          displayText: 'Song ${index + 1}',
          channelTitle: 'Artist ${index + 1}',
          thumbnailUrl: '',
        ),
        growable: false,
      );

      final container = ProviderContainer(
        overrides: [
          autoplaySuggestionLoaderProvider.overrideWithValue(
            (_) async => const [],
          ),
          autoplayRelatedLoaderProvider.overrideWithValue(
            (_) async => const [],
          ),
          autoplayMixLoaderProvider.overrideWithValue(
            (seed) async => MixPlaylistPage(
              playlistId: mixPlaylistIdFor(seed.videoId),
              tracks: mixTracks,
            ),
          ),
          autoplayMixPageLoaderProvider.overrideWithValue(
            (_, _) async => MixPlaylistPage.empty,
          ),
          autoplayAudioResolverProvider.overrideWithValue((suggestion) {
            started.add(suggestion.videoId);
            final completer = Completer<ResolvedAudio?>();
            pending[suggestion.videoId] = completer;
            return completer.future;
          }),
        ],
      );
      addTearDown(container.dispose);

      const tapped = YouTubeSearchSuggestion(
        videoId: 'song-0',
        displayText: 'Song 0',
        channelTitle: 'Artist 0',
        thumbnailUrl: '',
      );

      container.read(autoplayQueueControllerProvider.notifier).enqueue(const [
        tapped,
      ], 0);
      await pumpEventQueue();

      // Arranca por la cabeza de la cola y sin saturar la red: el cupo es
      // corto a proposito para no que YouTube marque la IP.
      expect(started, ['song-1', 'song-2']);

      pending['song-1']!.complete(null);
      await pumpEventQueue();

      // Al liberarse un cupo entra la siguiente pista, siempre en orden.
      expect(started, ['song-1', 'song-2', 'song-3']);
    },
  );

  test('puts the mix of the tapped song ahead of the rest of the search '
      'results', () async {
    final mixSeeds = <String>[];
    final refillSettled = Completer<void>();

    const tapped = YouTubeSearchSuggestion(
      videoId: 'tapped-song',
      displayText: 'Titi Me Pregunto',
      channelTitle: 'Bad Bunny',
      thumbnailUrl: '',
    );
    // Otro resultado de la misma busqueda, de un genero ajeno: ya no debe
    // colarse como "siguiente cancion".
    const unrelatedResult = YouTubeSearchSuggestion(
      videoId: 'unrelated-result',
      displayText: 'Best heavy metal riffs compilation',
      channelTitle: 'Random Channel',
      thumbnailUrl: '',
    );
    const mixOne = YouTubeSearchSuggestion(
      videoId: 'mix-one',
      displayText: 'Moscow Mule',
      channelTitle: 'Bad Bunny',
      thumbnailUrl: '',
    );
    const mixTwo = YouTubeSearchSuggestion(
      videoId: 'mix-two',
      displayText: 'Ojitos Lindos',
      channelTitle: 'Bad Bunny',
      thumbnailUrl: '',
    );

    // Un mix real trae unas 25 pistas: alcanza para llenar la cola sin tocar
    // el resto de la busqueda.
    final mixTracks = <YouTubeSearchSuggestion>[
      mixOne,
      mixTwo,
      ...List.generate(
        20,
        (index) => YouTubeSearchSuggestion(
          videoId: 'mix-filler-$index',
          displayText: 'Mix filler $index',
          channelTitle: 'Bad Bunny',
          thumbnailUrl: '',
        ),
      ),
    ];

    final container = ProviderContainer(
      overrides: [
        autoplaySuggestionLoaderProvider.overrideWithValue(
          (_) async => const [],
        ),
        autoplayRelatedLoaderProvider.overrideWithValue((_) async => const []),
        autoplayMixLoaderProvider.overrideWithValue((seed) async {
          mixSeeds.add(seed.videoId);
          return MixPlaylistPage(
            playlistId: mixPlaylistIdFor(seed.videoId),
            tracks: mixTracks,
          );
        }),
        autoplayMixPageLoaderProvider.overrideWithValue(
          (_, _) async => MixPlaylistPage.empty,
        ),
        autoplayAudioResolverProvider.overrideWithValue((_) async => null),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(autoplayQueueControllerProvider, (
      previous,
      next,
    ) {
      if ((previous?.isLoadingMore ?? false) &&
          !next.isLoadingMore &&
          !refillSettled.isCompleted) {
        refillSettled.complete();
      }
    });
    addTearDown(subscription.close);

    container.read(autoplayQueueControllerProvider.notifier).enqueue(const [
      tapped,
      unrelatedResult,
    ], 0);
    await refillSettled.future;

    final queue = container.read(autoplayQueueControllerProvider);
    expect(mixSeeds.first, tapped.videoId);
    // Lo que sigue sale del mix de la cancion tocada...
    expect(queue.upcoming.take(2).map((song) => song.videoId), [
      mixOne.videoId,
      mixTwo.videoId,
    ]);
    // ...y el resultado de otro genero queda detras, como red de seguridad.
    expect(queue.upcoming.last.videoId, unrelatedResult.videoId);
  });

  test('autoplay still has a next song when every source fails', () async {
    const tapped = YouTubeSearchSuggestion(
      videoId: 'tapped-song',
      displayText: 'Tapped song',
      channelTitle: 'Artist',
      thumbnailUrl: '',
    );
    const alsoInResults = YouTubeSearchSuggestion(
      videoId: 'also-in-results',
      displayText: 'Another result',
      channelTitle: 'Other artist',
      thumbnailUrl: '',
    );

    // Red caida: ni mix, ni relacionados, ni busqueda. La reproduccion continua
    // no puede quedarse muda por eso.
    final container = ProviderContainer(
      overrides: [
        autoplaySuggestionLoaderProvider.overrideWithValue(
          (_) async => const [],
        ),
        autoplayRelatedLoaderProvider.overrideWithValue((_) async => const []),
        autoplayMixLoaderProvider.overrideWithValue(
          (_) async => MixPlaylistPage.empty,
        ),
        autoplayMixPageLoaderProvider.overrideWithValue(
          (_, _) async => MixPlaylistPage.empty,
        ),
        autoplayAudioResolverProvider.overrideWithValue((_) async => null),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(autoplayQueueControllerProvider.notifier);
    notifier.enqueue(const [tapped, alsoInResults], 0);
    await pumpEventQueue();

    final next = await notifier.playNext();
    expect(next?.suggestion.videoId, alsoInResults.videoId);
    expect(
      container.read(autoplayQueueControllerProvider).current?.videoId,
      alsoInResults.videoId,
    );
  });

  test('keeps pulling from the same mix with its next-page token', () async {
    final pageRequests = <List<String>>[];
    final refillSettled = Completer<void>();

    const tapped = YouTubeSearchSuggestion(
      videoId: 'tapped-song',
      displayText: 'Titi Me Pregunto',
      channelTitle: 'Bad Bunny',
      thumbnailUrl: '',
    );
    const firstPageTrack = YouTubeSearchSuggestion(
      videoId: 'mix-page-one',
      displayText: 'Moscow Mule',
      channelTitle: 'Bad Bunny',
      thumbnailUrl: '',
    );
    const secondPageTrack = YouTubeSearchSuggestion(
      videoId: 'mix-page-two',
      displayText: 'Efecto',
      channelTitle: 'Bad Bunny',
      thumbnailUrl: '',
    );

    final container = ProviderContainer(
      overrides: [
        autoplaySuggestionLoaderProvider.overrideWithValue(
          (_) async => const [],
        ),
        autoplayRelatedLoaderProvider.overrideWithValue((_) async => const []),
        autoplayMixLoaderProvider.overrideWithValue(
          (seed) async => MixPlaylistPage(
            playlistId: mixPlaylistIdFor(seed.videoId),
            tracks: const [firstPageTrack],
            nextPageToken: 'page-two-token',
          ),
        ),
        autoplayMixPageLoaderProvider.overrideWithValue((
          playlistId,
          nextPageToken,
        ) async {
          pageRequests.add([playlistId, nextPageToken]);
          return const MixPlaylistPage(
            playlistId: 'RDtapped-song',
            tracks: [secondPageTrack],
          );
        }),
        autoplayAudioResolverProvider.overrideWithValue((_) async => null),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(autoplayQueueControllerProvider, (
      previous,
      next,
    ) {
      if ((previous?.isLoadingMore ?? false) &&
          !next.isLoadingMore &&
          !refillSettled.isCompleted) {
        refillSettled.complete();
      }
    });
    addTearDown(subscription.close);

    container.read(autoplayQueueControllerProvider.notifier).enqueue(const [
      tapped,
    ], 0);
    await refillSettled.future;

    // La continuacion se pide sobre el mismo mix, con el token que trajo la
    // pagina anterior: la cola no cambia de linea musical.
    expect(pageRequests.first, ['RDtapped-song', 'page-two-token']);
    expect(
      container
          .read(autoplayQueueControllerProvider)
          .upcoming
          .map((song) => song.videoId),
      containsAllInOrder([firstPageTrack.videoId, secondPageTrack.videoId]),
    );
  });

  test(
    'scrolling the queue keeps loading tracks past the usual ceiling',
    () async {
      var pageNumber = 0;
      List<YouTubeSearchSuggestion> pageTracks(int page) => List.generate(
        12,
        (index) => YouTubeSearchSuggestion(
          videoId: 'page$page-track$index',
          displayText: 'Track $page-$index',
          channelTitle: 'Artist',
          thumbnailUrl: '',
        ),
        growable: false,
      );

      final container = ProviderContainer(
        overrides: [
          autoplaySuggestionLoaderProvider.overrideWithValue(
            (_) async => const [],
          ),
          autoplayRelatedLoaderProvider.overrideWithValue(
            (_) async => const [],
          ),
          autoplayMixLoaderProvider.overrideWithValue((seed) async {
            final page = pageNumber++;
            return MixPlaylistPage(
              playlistId: mixPlaylistIdFor(seed.videoId),
              tracks: pageTracks(page),
              nextPageToken: 'token-$page',
            );
          }),
          autoplayMixPageLoaderProvider.overrideWithValue((
            playlistId,
            nextPageToken,
          ) async {
            final page = pageNumber++;
            return MixPlaylistPage(
              playlistId: playlistId,
              tracks: pageTracks(page),
              nextPageToken: 'token-$page',
            );
          }),
          autoplayAudioResolverProvider.overrideWithValue((_) async => null),
        ],
      );
      addTearDown(container.dispose);

      const tapped = YouTubeSearchSuggestion(
        videoId: 'tapped-song',
        displayText: 'Tapped song',
        channelTitle: 'Artist',
        thumbnailUrl: '',
      );

      final notifier = container.read(autoplayQueueControllerProvider.notifier);
      notifier.enqueue(const [tapped], 0);
      await pumpEventQueue();

      final ceiling = container
          .read(autoplayQueueControllerProvider)
          .upcoming
          .length;
      expect(ceiling, 20, reason: 'la cola se detiene en el techo normal');

      // Lo que hace la cola al llegar el usuario al final de la lista.
      await notifier.loadMoreUpcoming();
      await pumpEventQueue();

      final queue = container.read(autoplayQueueControllerProvider);
      expect(queue.upcoming.length, greaterThan(ceiling));
      // Ver mas no toca el prefetch: sigue mirando solo la cabeza de la cola.
      expect(queue.canLoadMore, isTrue);
    },
  );

  test('tapping an already played row jumps back to it', () async {
    final container = ProviderContainer(
      overrides: [
        autoplaySuggestionLoaderProvider.overrideWithValue(
          (_) async => const [],
        ),
        autoplayRelatedLoaderProvider.overrideWithValue((_) async => const []),
        autoplayMixLoaderProvider.overrideWithValue(
          (_) async => MixPlaylistPage.empty,
        ),
        autoplayMixPageLoaderProvider.overrideWithValue(
          (_, _) async => MixPlaylistPage.empty,
        ),
        autoplayAudioResolverProvider.overrideWithValue((_) async => null),
      ],
    );
    addTearDown(container.dispose);

    const first = YouTubeSearchSuggestion(
      videoId: 'song-one',
      displayText: 'Song one',
      channelTitle: 'Artist',
      thumbnailUrl: '',
    );
    const second = YouTubeSearchSuggestion(
      videoId: 'song-two',
      displayText: 'Song two',
      channelTitle: 'Artist',
      thumbnailUrl: '',
    );
    const third = YouTubeSearchSuggestion(
      videoId: 'song-three',
      displayText: 'Song three',
      channelTitle: 'Artist',
      thumbnailUrl: '',
    );

    final notifier = container.read(autoplayQueueControllerProvider.notifier);
    notifier.enqueue(const [first, second, third], 2);
    await pumpEventQueue();

    expect(container.read(autoplayQueueControllerProvider).currentPosition, 3);

    final jumped = notifier.playPlayedAt(0);
    expect(jumped?.suggestion.videoId, first.videoId);

    final queue = container.read(autoplayQueueControllerProvider);
    expect(queue.current?.videoId, first.videoId);
    expect(queue.played, isEmpty);
    expect(queue.currentPosition, 1);
    // Lo que sonaba y lo que quedaba en medio vuelven al frente, en orden.
    expect(queue.upcoming.take(2).map((song) => song.videoId), [
      second.videoId,
      third.videoId,
    ]);
  });
}
