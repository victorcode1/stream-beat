import 'dart:convert';
import 'dart:io';

import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/features/youtube_account/data/youtube_library_store.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_account_repository.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_cookie.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_library_parser.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object?> _text(String text, {String? browseId}) => {
  'runs': [
    {
      'text': text,
      if (browseId != null)
        'navigationEndpoint': {
          'browseEndpoint': {'browseId': browseId},
        },
    },
  ],
};

Map<String, Object?> _card(String title, String browseId) => {
  'musicTwoRowItemRenderer': {'title': _text(title, browseId: browseId)},
};

Map<String, Object?> _track(String videoId) => {
  'musicResponsiveListItemRenderer': {
    'playlistItemData': {'videoId': videoId},
    'flexColumns': [
      {
        'musicResponsiveListItemFlexColumnRenderer': {
          'text': _text('Cancion $videoId'),
        },
      },
    ],
  },
};

/// YouTube Music de mentira: una cuenta con «Me gusta», una lista propia y
/// una lista que StreamBeat ya habia creado.
class _FakeYouTube {
  final calls = <String>[];
  final liked = <String>[];
  final added = <String, List<String>>{};
  final created = <String>[];

  static const _remote = {
    'LM': ['aaaaaaaaaaa'],
    'PLrock': ['bbbbbbbbbbb'],
    'PLsbCorrer': ['ccccccccccc'],
  };

  MockClient get client => MockClient((request) async {
    final endpoint = request.url.path.replaceFirst('/youtubei/v1/', '');
    final body = jsonDecode(request.body) as Map<String, Object?>;
    calls.add(endpoint);
    return _json(switch (endpoint) {
      'browse' => _browse(body['browseId'] as String),
      'like/like' => _like(body),
      'playlist/create' => _create(body),
      'browse/edit_playlist' => _edit(body),
      _ => throw StateError('Endpoint inesperado: $endpoint'),
    });
  });

  Map<String, Object?> _browse(String browseId) {
    if (browseId == 'FEmusic_liked_playlists') {
      return {
        'gridRenderer': {
          'items': [
            _card('Me gusta', 'VLLM'),
            _card('Rock', 'VLPLrock'),
            _card('${streamBeatPlaylistPrefix}Correr', 'VLPLsbCorrer'),
          ],
        },
      };
    }
    final tracks = _remote[browseId.substring(2)] ?? const <String>[];
    return {
      'musicPlaylistShelfRenderer': {
        'contents': [for (final id in tracks) _track(id)],
      },
    };
  }

  Map<String, Object?> _like(Map<String, Object?> body) {
    final target = body['target'] as Map<String, Object?>;
    liked.add(target['videoId'] as String);
    return {};
  }

  Map<String, Object?> _create(Map<String, Object?> body) {
    expect(body['privacyStatus'], 'PRIVATE');
    created.add(body['title'] as String);
    return {'playlistId': 'PLnueva'};
  }

  Map<String, Object?> _edit(Map<String, Object?> body) {
    final actions = (body['actions'] as List).cast<Map<String, Object?>>();
    added[body['playlistId'] as String] = [
      for (final action in actions) action['addedVideoId'] as String,
    ];
    return {'status': 'STATUS_SUCCEEDED'};
  }

  http.Response _json(Map<String, Object?> data) {
    final page = {
      'responseContext': {
        'serviceTrackingParams': [
          {
            'params': [
              {'key': 'logged_in', 'value': '1'},
            ],
          },
        ],
      },
      ...data,
    };
    return http.Response.bytes(utf8.encode(jsonEncode(page)), 200);
  }
}

void main() {
  group('YouTubeMusicSync', () {
    test('baja la cuenta y sube solo lo que le falta a YouTube', () async {
      final youtube = _FakeYouTube();
      final repository = YouTubeMusicAccountRepository(
        YouTubeMusicCookie.tryParse('SAPISID=abc; SID=zzz')!,
        client: youtube.client,
      );

      final result = await YouTubeMusicSync(repository).run(
        favoriteIds: ['aaaaaaaaaaa', 'ddddddddddd', ''],
        playlists: const [
          StreamBeatSyncList(
            name: 'Correr',
            videoIds: ['ccccccccccc', 'eeeeeeeeeee', ''],
          ),
          StreamBeatSyncList(name: 'Nueva', videoIds: ['fffffffffff']),
          StreamBeatSyncList(name: 'Solo archivos', videoIds: ['']),
        ],
      );

      // Bajada: listas de la cuenta sin las de StreamBeat, y los «Me gusta».
      expect(result.library.map((saved) => saved.playlist.title), [
        'Me gusta',
        'Rock',
      ]);
      expect(result.library.last.tracks.single.videoId, 'bbbbbbbbbbb');
      expect(result.likedSongs.single.videoId, 'aaaaaaaaaaa');

      // Subida: solo la favorita sin «Me gusta» y lo que falta en las listas.
      expect(youtube.liked, ['ddddddddddd']);
      expect(youtube.created, ['${streamBeatPlaylistPrefix}Nueva']);
      expect(youtube.added, {
        'PLsbCorrer': ['eeeeeeeeeee'],
        'PLnueva': ['fffffffffff'],
      });
      expect(result.likesSent, 1);
      expect(result.playlistsCreated, 1);
      expect(result.songsSent, 2);
    });
  });

  group('YouTubeLibraryStore', () {
    late Directory directory;
    const store = YouTubeLibraryStore();

    setUpAll(() async {
      directory = await Directory.systemTemp.createTemp('streambeat_yt_lib_');
      Hive.init(directory.path);
      await Hive.openBox(youtubeLibraryBoxName);
    });

    tearDownAll(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });

    test('guarda y lee las listas con sus canciones', () async {
      await store.replaceAll(const [
        SavedYouTubePlaylist(
          playlist: YouTubeMusicPlaylist(
            id: 'LM',
            title: 'Me gusta',
            subtitle: 'Lista automática',
            thumbnailUrl: 'portada.jpg',
          ),
          tracks: [
            YouTubeSearchSuggestion(
              videoId: 'aaaaaaaaaaa',
              displayText: '¡Corre!',
              channelTitle: 'Jesse & Joy',
              thumbnailUrl: 'cancion.jpg',
              duration: Duration(minutes: 5, seconds: 55),
            ),
          ],
        ),
      ]);

      final saved = store.readAll().single;
      expect(saved.playlist.id, 'LM');
      expect(saved.playlist.subtitle, 'Lista automática');
      expect(saved.tracks.single.displayText, '¡Corre!');
      expect(
        saved.tracks.single.duration,
        const Duration(minutes: 5, seconds: 55),
      );

      await store.writeSyncedAt(DateTime(2026, 11, 20, 16, 30));
      expect(store.readSyncedAt(), DateTime(2026, 11, 20, 16, 30));

      await store.clear();
      expect(store.readAll(), isEmpty);
      expect(store.readSyncedAt(), isNull);
    });
  });
}
