import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/library/data/downloaded_audio.dart';
import 'package:flow_music/features/library/presentation/widgets/downloaded_file_actions.dart';
import 'package:flow_music/features/playlists/presentation/widgets/playlist_actions.dart';
import 'package:flow_music/features/song/presentation/controllers/song_controller.dart';
import 'package:flow_music/features/song/presentation/widgets/modern_player_widget.dart';
import 'package:flow_music/features/song/presentation/widgets/artist_name_button.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DownloadedAudioPlayerPage extends ConsumerStatefulWidget {
  const DownloadedAudioPlayerPage({super.key, required this.downloadedAudio});

  final DownloadedAudio downloadedAudio;

  @override
  ConsumerState<DownloadedAudioPlayerPage> createState() =>
      _DownloadedAudioPlayerPageState();
}

class _DownloadedAudioPlayerPageState
    extends ConsumerState<DownloadedAudioPlayerPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.downloadedAudio.isVideo) {
        ref.read(songController).playDownloadedVideo(widget.downloadedAudio);
      } else {
        ref.read(songController).playDownloadedAudio(widget.downloadedAudio);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = ref.watch(songController);
    final title = controller.displayTitle ?? widget.downloadedAudio.title;
    final author = controller.displayAuthor ?? widget.downloadedAudio.author;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            if (author.isNotEmpty)
              ArtistNameButton(
                artist: author,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: LocaleKeys.add_to_playlist.tr(),
            icon: const Icon(Icons.playlist_add_rounded),
            onPressed: () => showAddToPlaylistFlow(
              context: context,
              ref: ref,
              audio: widget.downloadedAudio,
            ),
          ),
        ],
      ),
      body: ModernPlayerWidget(
        audioPlayer: controller.audioPlayer,
        videoController: controller.videoPlayerController,
        videoTitle: controller.displayTitle,
        videoAuthor: controller.displayAuthor,
        thumbnailUrl: controller.displayThumbnailUrl,
        isLoading: controller.isLoading,
        isDownloading: false,
        isSavingOffline: false,
        isAudioDownloaded: true,
        isOfflineSaved: false,
        downloadProgress: 1,
        offlineProgress: 0,
        onDownloadPressed: () {
          if (widget.downloadedAudio.isVideo) {
            return controller.playDownloadedVideo(widget.downloadedAudio);
          }
          return controller.playDownloadedAudio(widget.downloadedAudio);
        },
        onDownloadedFilePressed: () => showDownloadedFileActions(
          context: context,
          audio: widget.downloadedAudio,
        ),
      ),
    );
  }
}
