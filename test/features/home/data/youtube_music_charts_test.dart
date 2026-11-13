import 'package:flow_music/features/home/data/youtube_music_charts.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _column(String renderer, String text) => {
  renderer: {
    'text': {
      'runs': [
        {'text': text},
      ],
    },
  },
};

Map<String, Object?> _row(String id, String title, String artist, String time) {
  return {
    'musicResponsiveListItemRenderer': {
      'playlistItemData': {'videoId': id},
      'flexColumns': [
        _column('musicResponsiveListItemFlexColumnRenderer', title),
        _column('musicResponsiveListItemFlexColumnRenderer', artist),
      ],
      'fixedColumns': [
        _column('musicResponsiveListItemFixedColumnRenderer', time),
      ],
    },
  };
}

void main() {
  test('finds the first chart playlist on the charts page', () {
    final charts = {
      'contents': [
        {
          'musicTwoRowItemRenderer': {
            'navigationEndpoint': {
              'browseEndpoint': {'browseId': 'MPREartist'},
            },
          },
        },
        {
          'musicTwoRowItemRenderer': {
            'navigationEndpoint': {
              'browseEndpoint': {'browseId': 'VLtendencias'},
            },
          },
        },
      ],
    };

    expect(chartPlaylistIdFrom(charts), 'VLtendencias');
    expect(chartPlaylistIdFrom(const {}), isNull);
  });

  test('reads chart tracks in order with artist and duration', () {
    final playlist = [
      _row('a1', 'Gansterismo', 'Valentino GRM y Yemil', '3:31'),
      _row('b2', 'BANDALO', 'Don Pablo Mures', '1:40'),
      _row('a1', 'Repetida', 'Otro', '2:00'),
      _row('', 'Sin video', 'Nadie', '2:00'),
    ];

    final tracks = parseChartTracks(playlist);

    expect(tracks.map((track) => track.videoId), ['a1', 'b2']);
    expect(tracks.first.displayText, 'Gansterismo');
    expect(tracks.first.channelTitle, 'Valentino GRM y Yemil');
    expect(tracks.first.duration, const Duration(minutes: 3, seconds: 31));
    expect(
      tracks.first.thumbnailUrl,
      'https://i.ytimg.com/vi/a1/hqdefault.jpg',
    );
  });
}
