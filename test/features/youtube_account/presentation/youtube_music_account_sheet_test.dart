import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/features/youtube_account/data/youtube_library_store.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_account_repository.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_library_parser.dart';
import 'package:flow_music/features/youtube_account/presentation/controllers/youtube_music_account_controller.dart';
import 'package:flow_music/features/youtube_account/presentation/widgets/youtube_music_account_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

YouTubeSearchSuggestion _song(String id) => YouTubeSearchSuggestion(
  videoId: id,
  displayText: id,
  channelTitle: '',
  thumbnailUrl: '',
);

SavedYouTubePlaylist _saved(String id, int songs) => SavedYouTubePlaylist(
  playlist: YouTubeMusicPlaylist(
    id: id,
    title: id,
    subtitle: '',
    thumbnailUrl: '',
  ),
  tracks: [for (var i = 0; i < songs; i++) _song('$id$i')],
);

class _FakeLibrary extends YouTubeLibraryController {
  @override
  List<SavedYouTubePlaylist> build() => [
    _saved('LM', 3),
    _saved('PLrock', 1),
    _saved('PLpop', 1),
  ];
}

class _FakeLastSync extends YouTubeLastSyncController {
  @override
  DateTime? build() => DateTime(2026, 11, 20, 16, 30);
}

Future<void> _openSheet(
  WidgetTester tester,
  Future<YouTubeMusicAccountInfo?> Function() info,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        youtubeMusicAccountInfoProvider.overrideWith((ref) => info()),
        youtubeLibraryProvider.overrideWith(_FakeLibrary.new),
        youtubeLastSyncProvider.overrideWith(_FakeLastSync.new),
        youtubeSubscribedArtistsCountProvider.overrideWith((ref) async => 7),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showYouTubeMusicAccountSheet(context),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra perfil, Premium, correo y contadores', (tester) async {
    await _openSheet(
      tester,
      () async => const YouTubeMusicAccountInfo(
        name: 'Victor',
        handle: '@victor',
        photoUrl: '',
        email: 'yo@ejemplo.com',
        hasPremium: true,
      ),
    );

    expect(find.text('Victor'), findsOneWidget);
    expect(find.text('@victor'), findsOneWidget);
    expect(find.text('yo@ejemplo.com'), findsOneWidget);
    expect(find.text(LocaleKeys.yt_account_premium), findsOneWidget);
    // 2 listas sin contar «Me gusta», 3 «Me gusta» y 7 artistas.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text(LocaleKeys.yt_account_open_channel), findsOneWidget);
    expect(find.text(LocaleKeys.yt_account_session_expired), findsNothing);
  });

  testWidgets('sin Premium ni correo no muestra esas lineas', (tester) async {
    await _openSheet(
      tester,
      () async => const YouTubeMusicAccountInfo(
        name: 'Victor',
        handle: '',
        photoUrl: '',
        hasPremium: false,
      ),
    );

    expect(find.text(LocaleKeys.yt_account_premium), findsNothing);
    expect(find.text(LocaleKeys.yt_account_open_channel), findsNothing);
  });

  testWidgets('con la sesion vencida pide volver a iniciarla', (tester) async {
    await _openSheet(
      tester,
      () => Future.error(const YouTubeMusicSessionExpired()),
    );

    expect(find.text(LocaleKeys.yt_account_session_expired), findsOneWidget);
    expect(find.text(LocaleKeys.yt_account_sign_in_again), findsOneWidget);
    expect(find.text(LocaleKeys.yt_account_stat_artists), findsNothing);
  });

  testWidgets('desconectar pide confirmacion', (tester) async {
    await _openSheet(
      tester,
      () async => const YouTubeMusicAccountInfo(
        name: 'Victor',
        handle: '@victor',
        photoUrl: '',
      ),
    );

    await tester.tap(find.text(LocaleKeys.yt_account_disconnect));
    await tester.pumpAndSettle();

    expect(
      find.text(LocaleKeys.yt_account_disconnect_confirm_title),
      findsOneWidget,
    );
  });
}
