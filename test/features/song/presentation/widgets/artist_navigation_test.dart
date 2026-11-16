import 'package:flow_music/app/main_app_controller.dart';
import 'package:flow_music/core/audio/now_playing_provider.dart';
import 'package:flow_music/features/autoplay/presentation/controllers/autoplay_queue_controller.dart';
import 'package:flow_music/features/home/presentation/controllers/home_view_controller.dart';
import 'package:flow_music/features/settings/presentation/controllers/default_playback_mode_controller.dart';
import 'package:flow_music/features/favorites/data/favorite_song.dart';
import 'package:flow_music/features/favorites/presentation/controllers/favorites_controller.dart';
import 'package:flow_music/features/home/presentation/widgets/app_bar.dart';
import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/features/search/presentation/providers/list_quick_search_data.dart';
import 'package:flow_music/features/settings/presentation/controllers/autoplay_enabled_controller.dart';
import 'package:flow_music/features/song/presentation/controllers/song_controller.dart';
import 'package:flow_music/features/song/presentation/widgets/artist_name_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class TestSongController extends SongController {
  TestSongController({required super.ref});
  final selections = <String>[];
  @override
  Future<void> playAudio({required String id, Duration? knownDuration}) async {
    selections.add(id);
  }

  @override
  String? get displayTitle => 'Current song';
  @override
  String? get displayAuthor => 'Artist';
  @override
  Future<void> autoPlay({required String id, Duration? knownDuration}) async {
    selections.add(id);
  }
}

class TestResults extends SearchDataReq {
  @override
  Future<List<YouTubeSearchSuggestion>> build({
    required String? search,
  }) async => const [
    YouTubeSearchSuggestion(
      videoId: 'another',
      displayText: 'Another song',
      channelTitle: 'Artist',
      thumbnailUrl: '',
    ),
    YouTubeSearchSuggestion(
      videoId: 'following',
      displayText: 'Following song',
      channelTitle: 'Artist',
      thumbnailUrl: '',
    ),
  ];
}

class AudioDefault extends DefaultPlaybackModeController {
  @override
  PlaybackMode build() => PlaybackMode.audio;
}

class NoAutoplay extends AutoplayEnabledController {
  @override
  bool build() => false;
}

class NoFavorites extends FavoritesController {
  @override
  List<FavoriteSong> build() => [];
}

void main() {
  test(
    'choosing a search result starts playback without mounting the player route',
    () {
      late TestSongController controller;
      final container = ProviderContainer(
        overrides: [
          songController.overrideWith(
            (ref) => controller = TestSongController(ref: ref),
          ),
          defaultPlaybackModeControllerProvider.overrideWith(AudioDefault.new),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(homeViewProvider.notifier)
          .listen(
            const YouTubeSearchSuggestion(
              videoId: 'chosen',
              displayText: 'Chosen song',
              channelTitle: 'Artist',
              thumbnailUrl: '',
            ),
          );
      expect(controller.selections, ['chosen']);
    },
  );

  testWidgets(
    'artist selection stays visible and Next plays the following artist song',
    (tester) async {
      late TestSongController controller;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            songController.overrideWith(
              (ref) => controller = TestSongController(ref: ref),
            ),
            searchDataReqProvider(
              search: 'Artist',
            ).overrideWith(TestResults.new),
            autoplayEnabledControllerProvider.overrideWith(NoAutoplay.new),
            nowPlayingIsPlayingProvider.overrideWith(
              (ref) => Stream.value(false),
            ),
            autoplayAudioResolverProvider.overrideWithValue((_) async => null),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ArtistNameButton(artist: 'Artist')),
          ),
        ),
      );
      await tester.tap(find.text('Artist'));
      await tester.pumpAndSettle();
      // The controller is created only when the user actually selects a song.
      expect(find.text('Another song'), findsOneWidget);
      await tester.tap(find.text('Another song'));
      await tester.pumpAndSettle();
      expect(controller.selections, ['another']);
      expect(find.text('Another song'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ArtistNameButton)),
      );
      expect(
        container.read(autoplayQueueControllerProvider).isCollection,
        isTrue,
      );
      await container.read(mainAppControllerProvider).handleSkipToNext();
      await tester.pumpAndSettle();
      expect(controller.selections, ['another', 'following']);
      expect(controller.currentVideoId, 'following');
      expect(find.text('Following song'), findsOneWidget);
      final following = tester.getSemantics(find.text('Following song'));
      expect(
        following,
        matchesSemantics(
          isSelected: true,
          hasSelectedState: true,
          isButton: true,
          isFocusable: true,
          hasFocusAction: true,
          hasTapAction: true,
          label: 'Following song\nArtist',
        ),
      );
      await container.read(mainAppControllerProvider).handleSkipToNext();
      await tester.pumpAndSettle();
      expect(controller.selections, ['another', 'following', 'another']);
      expect(controller.currentVideoId, 'another');
    },
  );

  testWidgets(
    'player app bar leaves title and artist to the player and puts the three actions in overflow',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            songController.overrideWith((ref) => TestSongController(ref: ref)),
            favoritesControllerProvider.overrideWith(NoFavorites.new),
            nowPlayingTitleProvider.overrideWith(
              (ref) => Stream.value('Current song'),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppAbarMain(
                showSearch: () async {},
                showNowPlayingDetails: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Titulo y artista ya estan grandes en el reproductor: la barra no
      // los repite.
      expect(find.text('Current song'), findsNothing);
      expect(find.text('Artist'), findsNothing);
      expect(find.textContaining('REPRODUCIENDO'), findsNothing);
      expect(find.byIcon(Icons.queue_music_rounded), findsNothing);
      expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
      expect(find.byIcon(Icons.videocam_outlined), findsNothing);
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.queue_music_rounded), findsOneWidget);
      expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
    },
  );
}
