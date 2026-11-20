import 'dart:convert';

import 'package:flow_music/features/search/data/repositories/youtube_suggestions_repository.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_account_repository.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_cookie.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_library_parser.dart';
import 'package:flutter_test/flutter_test.dart';
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

Map<String, Object?> _playlistCard(String title, String? browseId) => {
  'musicTwoRowItemRenderer': {
    'title': _text(title, browseId: browseId),
    'subtitle': _text('Lista • 12 canciones'),
    'thumbnailRenderer': {
      'musicThumbnailRenderer': {
        'thumbnail': {
          'thumbnails': [
            {'url': 'small.jpg'},
            {'url': 'large.jpg'},
          ],
        },
      },
    },
  },
};

Map<String, Object?> _track(String videoId, String title, String length) => {
  'musicResponsiveListItemRenderer': {
    'playlistItemData': {'videoId': videoId},
    'flexColumns': [
      {
        'musicResponsiveListItemFlexColumnRenderer': {'text': _text(title)},
      },
      {
        'musicResponsiveListItemFlexColumnRenderer': {
          'text': _text('Jesse & Joy'),
        },
      },
    ],
    'fixedColumns': [
      {
        'musicResponsiveListItemFixedColumnRenderer': {'text': _text(length)},
      },
    ],
  },
};

Map<String, Object?> _continuation(String token) => {
  'continuationItemRenderer': {
    'continuationEndpoint': {
      'continuationCommand': {'token': token},
    },
  },
};

Map<String, Object?> _loggedIn(String value) => {
  'serviceTrackingParams': [
    {
      'service': 'GFEEDBACK',
      'params': [
        {'key': 'logged_in', 'value': value},
      ],
    },
  ],
};

/// Primera pagina de una lista: canciones, token propio y, aparte, una
/// seccion de sugerencias con su propio token que no debe seguirse.
Map<String, Object?> _firstTracksPage() => {
  'responseContext': _loggedIn('1'),
  'contents': {
    'twoColumnBrowseResultsRenderer': {
      'secondaryContents': {
        'sectionListRenderer': {
          'contents': [
            {
              'musicPlaylistShelfRenderer': {
                'contents': [
                  _track('aaaaaaaaaaa', '¡Corre!', '5:55'),
                  _track('bbbbbbbbbbb', 'Dueles', '3:58'),
                  _continuation('tracks-2'),
                ],
              },
            },
            {
              'musicShelfRenderer': {
                'contents': [_track('zzzzzzzzzzz', 'Sugerida', '3:00')],
              },
            },
          ],
          'continuations': [
            {
              'nextContinuationData': {'continuation': 'related'},
            },
          ],
        },
      },
    },
  },
};

Map<String, Object?> _secondTracksPage() => {
  'responseContext': _loggedIn('1'),
  'onResponseReceivedActions': [
    {
      'appendContinuationItemsAction': {
        'continuationItems': [_track('ccccccccccc', 'Ecos de amor', '4:01')],
      },
    },
  ],
};

Map<String, Object?> _shelf(String title, List<Map<String, Object?>> items) => {
  'musicCarouselShelfRenderer': {
    'header': {
      'musicCarouselShelfBasicHeaderRenderer': {'title': _text(title)},
    },
    'contents': items,
  },
};

Map<String, Object?> _songCard(String videoId, String title) => {
  'musicTwoRowItemRenderer': {
    'title': _text(title),
    'subtitle': _text('Canción • Jesse & Joy'),
    'navigationEndpoint': {
      'watchEndpoint': {'videoId': videoId},
    },
  },
};

Map<String, Object?> _albumCard(String title, String playlistId) => {
  'musicTwoRowItemRenderer': {
    'title': _text(title, browseId: 'MPREb_album'),
    'subtitle': _text('Álbum • 2017'),
    'navigationEndpoint': {
      'browseEndpoint': {'browseId': 'MPREb_album'},
    },
    'thumbnailOverlay': {
      'musicItemThumbnailOverlayRenderer': {
        'content': {
          'musicPlayButtonRenderer': {
            'playNavigationEndpoint': {
              'watchPlaylistEndpoint': {'playlistId': playlistId},
            },
          },
        },
      },
    },
  },
};

Map<String, Object?> _homePage() => {
  'responseContext': _loggedIn('1'),
  'contents': {
    'singleColumnBrowseResultsRenderer': {
      'tabs': [
        {
          'tabRenderer': {
            'content': {
              'sectionListRenderer': {
                'contents': [
                  _shelf('Volver a escuchar', [
                    _songCard('aaaaaaaaaaa', '¡Corre!'),
                    _albumCard('Un besito más', 'OLAK5uy_album'),
                    _playlistCard('Un artista', 'UCartist'),
                  ]),
                  _shelf('Selección rápida', [
                    _track('bbbbbbbbbbb', 'Dueles', '3:58'),
                  ]),
                  _shelf('Solo artistas', [
                    _playlistCard('Un artista', 'UCartist'),
                  ]),
                ],
                'continuations': [
                  {
                    'nextContinuationData': {'continuation': 'home-2'},
                  },
                ],
              },
            },
          },
        },
      ],
    },
  },
};

void main() {
  group('YouTubeMusicCookie', () {
    test('lee SAPISID del encabezado pegado y firma la peticion', () {
      final cookie = YouTubeMusicCookie.tryParse(
        'Cookie: VISITOR=x; SAPISID=abc123; SID=zzz\n',
      );

      expect(cookie, isNotNull);
      expect(cookie!.header, 'VISITOR=x; SAPISID=abc123; SID=zzz');
      expect(
        cookie.authorization(
          DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
        ),
        'SAPISIDHASH 1700000000_597a8411c1c01f9c14cea84b6ec377b76d93be6e',
      );
    });

    test('usa __Secure-3PAPISID cuando no viene SAPISID', () {
      expect(
        YouTubeMusicCookie.tryParse('__Secure-3PAPISID=abc123; SID=zzz'),
        isNotNull,
      );
    });

    test('rechaza cookies sin la cookie que firma la sesion', () {
      expect(YouTubeMusicCookie.tryParse('SID=zzz; HSID=yyy'), isNull);
      expect(YouTubeMusicCookie.tryParse('   '), isNull);
    });
  });

  group('YouTubeMusicLibraryParser', () {
    const parser = YouTubeMusicLibraryParser();

    test('lee las listas de la biblioteca y omite «Nueva lista»', () {
      final page = parser.parsePlaylists({
        'contents': {
          'gridRenderer': {
            'items': [
              _playlistCard('Nueva lista', null),
              _playlistCard('Me gusta', 'VLLM'),
              _playlistCard('Para correr', 'VLPLabc'),
              _playlistCard('Un artista', 'UCartist'),
            ],
            'continuations': [
              {
                'nextContinuationData': {'continuation': 'grid-2'},
              },
            ],
          },
        },
      });

      expect(page.items.map((playlist) => playlist.id), ['LM', 'PLabc']);
      expect(page.items.first.title, 'Me gusta');
      expect(page.items.first.subtitle, 'Lista • 12 canciones');
      expect(page.items.first.thumbnailUrl, 'large.jpg');
      expect(page.continuation, 'grid-2');
    });

    test('lee solo las canciones de la lista y su propio token', () {
      final page = parser.parseTracks(_firstTracksPage());

      expect(page.items.map((song) => song.videoId), [
        'aaaaaaaaaaa',
        'bbbbbbbbbbb',
      ]);
      expect(page.items.first.channelTitle, 'Jesse & Joy');
      expect(
        page.items.first.duration,
        const Duration(minutes: 5, seconds: 55),
      );
      expect(page.continuation, 'tracks-2');
    });

    test('lee las filas del Inicio con canciones, albumes y listas', () {
      final page = parser.parseHome(_homePage());

      expect(page.items.map((shelf) => shelf.title), [
        'Volver a escuchar',
        'Selección rápida',
      ]);
      final again = page.items.first;
      expect(again.items, hasLength(2));
      expect(again.items.first.song?.videoId, 'aaaaaaaaaaa');
      expect(again.items.first.subtitle, 'Canción');
      expect(again.items.last.playlist?.id, 'OLAK5uy_album');
      expect(again.songs.map((song) => song.videoId), ['aaaaaaaaaaa']);
      expect(page.items.last.items.single.song?.displayText, 'Dueles');
      expect(page.continuation, 'home-2');
    });

    test('lee nombre, usuario y foto de la cuenta', () {
      final account = parser.parseAccount({
        'actions': [
          {
            'openPopupAction': {
              'popup': {
                'multiPageMenuRenderer': {
                  'header': {
                    'activeAccountHeaderRenderer': {
                      'accountName': _text('Victor'),
                      'channelHandle': _text('@victor'),
                      'accountPhoto': {
                        'thumbnails': [
                          {'url': 'foto-48.jpg'},
                          {'url': 'foto-88.jpg'},
                        ],
                      },
                    },
                  },
                },
              },
            },
          },
        ],
      });

      expect(account?.name, 'Victor');
      expect(account?.handle, '@victor');
      expect(account?.photoUrl, 'foto-88.jpg');
      expect(parser.parseAccount(const {'actions': []}), isNull);
    });

    Map<String, Object?> accountMenu({Object? email, String? premium}) => {
      if (premium != null)
        'responseContext': {
          'serviceTrackingParams': [
            {
              'service': 'GFEEDBACK',
              'params': [
                {'key': 'has_unlimited_entitlement', 'value': premium},
              ],
            },
          ],
        },
      'actions': [
        {
          'openPopupAction': {
            'popup': {
              'multiPageMenuRenderer': {
                'header': {
                  'activeAccountHeaderRenderer': {
                    'accountName': _text('Victor'),
                    'email': ?email,
                  },
                },
              },
            },
          },
        },
      ],
    };

    test('Premium sale de has_unlimited_entitlement', () {
      expect(
        parser.parseAccount(accountMenu(premium: 'True'))?.hasPremium,
        isTrue,
      );
      expect(
        parser.parseAccount(accountMenu(premium: 'False'))?.hasPremium,
        isFalse,
      );
      expect(parser.parseAccount(accountMenu())?.hasPremium, isNull);
    });

    test('el correo se lee en texto o en runs y falta si no viene', () {
      expect(
        parser.parseAccount(accountMenu(email: 'yo@ejemplo.com'))?.email,
        'yo@ejemplo.com',
      );
      expect(
        parser.parseAccount(accountMenu(email: _text('yo@ejemplo.com')))?.email,
        'yo@ejemplo.com',
      );
      expect(parser.parseAccount(accountMenu())?.email, isEmpty);
    });

    test('cuenta los artistas suscritos sin repetir', () {
      Map<String, Object?> artist(String id) => {
        'musicResponsiveListItemRenderer': {
          'navigationEndpoint': {
            'browseEndpoint': {'browseId': id},
          },
        },
      };
      final page = parser.parseSubscribedArtists({
        'contents': {
          'musicShelfRenderer': {
            'contents': [
              artist('UCuno'),
              artist('UCdos'),
              artist('UCuno'),
              artist('MPREb_album'),
              _continuation('artists-2'),
            ],
          },
        },
      });

      expect(page.items, ['UCuno', 'UCdos']);
      expect(page.continuation, 'artists-2');
    });

    test('lee la cola de un mix', () {
      final songs = parser.parseMixTracks({
        'contents': [
          {
            'playlistPanelVideoRenderer': {
              'videoId': 'ccccccccccc',
              'title': _text('Ecos de amor'),
              'longBylineText': _text('Jesse & Joy • 617 M de vistas'),
              'lengthText': _text('3:34'),
            },
          },
        ],
      });

      expect(songs.single.displayText, 'Ecos de amor');
      expect(songs.single.channelTitle, 'Jesse & Joy');
      expect(songs.single.duration, const Duration(minutes: 3, seconds: 34));
    });
  });

  group('YouTubeMusicAccountRepository', () {
    final cookie = YouTubeMusicCookie.tryParse('SAPISID=abc123; SID=zzz')!;

    test('envia la sesion y sigue las paginas de la lista', () async {
      final requests = <Map<String, Object?>>[];
      final client = MockClient((request) async {
        expect(request.headers['cookie'], 'SAPISID=abc123; SID=zzz');
        expect(request.headers['authorization'], startsWith('SAPISIDHASH '));
        expect(request.headers['x-origin'], 'https://music.youtube.com');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        requests.add(body);
        final page = body['continuation'] == null
            ? _firstTracksPage()
            : _secondTracksPage();
        return http.Response.bytes(utf8.encode(jsonEncode(page)), 200);
      });

      final songs = await YouTubeMusicAccountRepository(
        cookie,
        client: client,
      ).fetchPlaylistTracks('PLabc');

      expect(songs.map((song) => song.displayText), [
        '¡Corre!',
        'Dueles',
        'Ecos de amor',
      ]);
      expect(requests.first['browseId'], 'VLPLabc');
      expect(requests.last['continuation'], 'tracks-2');
      expect(requests, hasLength(2));
    });

    test(
      'los mixes se piden como cola y las paginas antiguas por URL',
      () async {
        final uris = <Uri>[];
        final client = MockClient((request) async {
          uris.add(request.url);
          final body = jsonDecode(request.body) as Map<String, Object?>;
          final page = body['continuation'] == null
              ? _homePage()
              : {'responseContext': _loggedIn('1')};
          return http.Response.bytes(utf8.encode(jsonEncode(page)), 200);
        });
        final repository = YouTubeMusicAccountRepository(
          cookie,
          client: client,
        );

        final shelves = await repository.fetchHome();
        await repository.fetchPlaylistTracks('RDAMVMaaaaaaaaaaa');

        expect(shelves, hasLength(2));
        expect(uris[0].path, '/youtubei/v1/browse');
        expect(uris[1].queryParameters['ctoken'], 'home-2');
        expect(uris[1].queryParameters['type'], 'next');
        expect(uris[2].path, '/youtubei/v1/next');
      },
    );

    test(
      'la busqueda va firmada para cada sitio y sin sesion si falla',
      () async {
        final calls = <(String, String?)>[];
        final client = MockClient((request) async {
          final signed = request.headers['authorization'];
          calls.add((request.url.host, request.headers['x-origin']));
          // La busqueda de videos con sesion falla: debe repetirse sin ella.
          if (request.url.host == 'www.youtube.com' && signed != null) {
            return http.Response('', 500);
          }
          final page = {
            'contents': [_track('aaaaaaaaaaa', '¡Corre!', '5:55')],
          };
          return http.Response.bytes(utf8.encode(jsonEncode(page)), 200);
        });

        final results = await http.runWithClient(
          () => searchSongsAndVideos(
            'jesse y joy',
            includeMusic: true,
            session: (origin) => cookie.sessionHeaders(origin, DateTime(2026)),
          ),
          () => client,
        );

        expect(results.single.videoId, 'aaaaaaaaaaa');
        expect(
          calls,
          containsAll([
            ('music.youtube.com', 'https://music.youtube.com'),
            ('www.youtube.com', 'https://www.youtube.com'),
            ('www.youtube.com', null),
          ]),
        );
      },
    );

    test('la radio de la cuenta trae canciones y sigue por paginas', () async {
      Map<String, Object?> panelSong(String id) => {
        'playlistPanelVideoRenderer': {
          'videoId': id,
          'title': _text('Cancion $id'),
          'longBylineText': _text('Artista • 1 M de vistas'),
        },
      };
      final bodies = <Map<String, Object?>>[];
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        bodies.add(body);
        expect(request.url.path, '/youtubei/v1/next');
        final page = body['continuation'] == null
            ? {
                'contents': {
                  'playlistPanelRenderer': {
                    'contents': [panelSong('aaaaaaaaaaa')],
                    'continuations': [
                      {
                        'nextRadioContinuationData': {
                          'continuation': 'radio-2',
                        },
                      },
                    ],
                  },
                },
              }
            : {
                // La continuacion repite la cola original en contents.
                'contents': {
                  'playlistPanelRenderer': {
                    'contents': [panelSong('aaaaaaaaaaa')],
                  },
                },
                'continuationContents': {
                  'playlistPanelContinuation': {
                    'contents': [panelSong('bbbbbbbbbbb')],
                  },
                },
              };
        return http.Response.bytes(utf8.encode(jsonEncode(page)), 200);
      });
      final repository = YouTubeMusicAccountRepository(cookie, client: client);

      final first = await repository.fetchRadio('aaaaaaaaaaa');
      final next = await repository.fetchRadioPage(
        first.playlistId,
        first.nextPageToken!,
      );

      expect(first.playlistId, 'RDAMVMaaaaaaaaaaa');
      expect(first.tracks.single.channelTitle, 'Artista');
      expect(bodies.first['videoId'], 'aaaaaaaaaaa');
      expect(next.tracks.map((song) => song.videoId), ['bbbbbbbbbbb']);
      expect(next.hasNextPage, isFalse);
    });

    test('una cookie vencida responde como invitado y se reporta', () async {
      final client = MockClient(
        (_) async =>
            http.Response(jsonEncode({'responseContext': _loggedIn('0')}), 200),
      );

      await expectLater(
        YouTubeMusicAccountRepository(cookie, client: client).fetchPlaylists(),
        throwsA(isA<YouTubeMusicSessionExpired>()),
      );
    });

    test('un 401 tambien cuenta como sesion vencida', () async {
      final client = MockClient((_) async => http.Response('', 401));

      await expectLater(
        YouTubeMusicAccountRepository(cookie, client: client).fetchPlaylists(),
        throwsA(isA<YouTubeMusicSessionExpired>()),
      );
    });
  });
}
