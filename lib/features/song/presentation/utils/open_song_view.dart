import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/features/song/presentation/pages/song.dart';
import 'package:flutter/material.dart';

/// Abre la vista de la cancion encima de la pantalla actual, igual que las
/// listas de la Biblioteca. La propia vista arranca el audio (o lo deja seguir
/// si esa cancion ya suena), asi que quien la abre solo prepara la cola.
Future<void> openSongView(BuildContext context, YouTubeSearchSuggestion song) {
  final duration = song.duration;
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SongWidget(
        standalone: true,
        data: {
          'idSong': song.videoId,
          'playListId': '',
          if (duration != null) 'durationMs': '${duration.inMilliseconds}',
        },
      ),
    ),
  );
}
