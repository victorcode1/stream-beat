import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/features/search/data/repositories/youtube_music_search_parser.dart';
import 'package:flow_music/features/search/data/repositories/youtube_search_page_parser.dart';
import 'package:flow_music/features/search/data/repositories/youtube_suggestions_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _musicRow(String id, String title, List<String> details) {
  return {
    'musicResponsiveListItemRenderer': {
      'playlistItemData': {'videoId': id},
      'flexColumns': [
        {
          'musicResponsiveListItemFlexColumnRenderer': {
            'text': {
              'runs': [
                {'text': title},
              ],
            },
          },
        },
        {
          'musicResponsiveListItemFlexColumnRenderer': {
            'text': {
              'runs': [
                for (final (index, part) in details.indexed) ...[
                  if (index > 0) {'text': ' • '},
                  {'text': part},
                ],
              ],
            },
          },
        },
      ],
    },
  };
}

Map<String, Object?> _videoRow(String id, String title, String length) {
  return {
    'videoRenderer': {
      'videoId': id,
      'title': {
        'runs': [
          {'text': title},
        ],
      },
      'ownerText': {
        'runs': [
          {'text': 'Canal'},
        ],
      },
      'lengthText': {'simpleText': length},
    },
  };
}

YouTubeSearchSuggestion _suggestion(String id) => YouTubeSearchSuggestion(
  videoId: id,
  displayText: id,
  channelTitle: '',
  thumbnailUrl: '',
);

void main() {
  group('YouTubeMusicSearchParser', () {
    test('reads title, artist and duration from each song row', () {
      final data = {
        'contents': [
          _musicRow('abc123', 'Amor y Control', [
            'Rubén Blades',
            'Amor Y Control',
            '5:53',
          ]),
          _musicRow('def456', 'Pedro Navaja', [
            'Rubén Blades',
            'Siembra',
            '1:07:23',
          ]),
        ],
      };

      final results = const YouTubeMusicSearchParser().parseSuggestions(data);

      expect(results, hasLength(2));
      expect(results.first.videoId, 'abc123');
      expect(results.first.displayText, 'Amor y Control');
      expect(results.first.channelTitle, 'Rubén Blades');
      expect(results.first.duration, const Duration(minutes: 5, seconds: 53));
      expect(
        results.first.thumbnailUrl,
        'https://i.ytimg.com/vi/abc123/hqdefault.jpg',
      );
      expect(
        results.last.duration,
        const Duration(hours: 1, minutes: 7, seconds: 23),
      );
    });

    test('skips rows without a video and repeated videos', () {
      final data = [
        _musicRow('', 'Sin video', ['Artista', '3:00']),
        _musicRow('abc123', 'Uno', ['Artista', '3:00']),
        _musicRow('abc123', 'Uno otra vez', ['Artista', '3:00']),
      ];

      final results = const YouTubeMusicSearchParser().parseSuggestions(data);

      expect(results.map((item) => item.videoId), ['abc123']);
    });
  });

  test('user search keeps long videos but still drops Shorts', () {
    final data = [
      _videoRow('mix', 'Mix de salsa', '1:02:10'),
      _videoRow('song', 'Canción', '3:45'),
      _videoRow('short', 'Short', '0:20'),
    ];
    const parser = YouTubeSearchPageParser();

    final userResults = parser.parseSuggestionsFromData(
      data,
      minDuration: const Duration(seconds: 30),
      maxDuration: null,
    );
    final autoplayResults = parser.parseSuggestionsFromData(data);

    expect(userResults.map((item) => item.videoId), ['mix', 'song']);
    expect(autoplayResults.map((item) => item.videoId), ['song']);
  });

  test('mergeSearchResults keeps order, removes duplicates and limits', () {
    final merged = mergeSearchResults([
      [_suggestion('a'), _suggestion('b')],
      [_suggestion('b'), _suggestion('c'), _suggestion('d')],
    ], limit: 3);

    expect(merged.map((item) => item.videoId), ['a', 'b', 'c']);
  });
}
