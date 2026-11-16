import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/shared/widgets/song_row.dart';
import 'package:flutter/material.dart';

class ArtistSongTile extends StatelessWidget {
  const ArtistSongTile({
    super.key,
    required this.song,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
  });

  final YouTubeSearchSuggestion song;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: isCurrent,
      child: Material(
        color: isCurrent
            ? Color.alphaBlend(
                colors.primary.withValues(alpha: 0.12),
                colors.surfaceContainerHigh,
              )
            : colors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isCurrent
                ? colors.primary.withValues(alpha: 0.6)
                : colors.outline.withValues(alpha: 0.1),
            width: isCurrent ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: SongRow(
          title: song.displayText,
          subtitle: song.channelTitle,
          artworkUrl: song.thumbnailUrl,
          duration: song.duration,
          isCurrent: isCurrent,
          isPlaying: isPlaying,
          padding: const EdgeInsets.all(14),
          onTap: onTap,
          trailing: IconButton.filled(
            onPressed: onTap,
            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
            tooltip: isPlaying ? LocaleKeys.pause.tr() : LocaleKeys.play.tr(),
          ),
        ),
      ),
    );
  }
}
