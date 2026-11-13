import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/audio_tools/presentation/controllers/audio_tools_controller.dart';
import 'package:flow_music/features/autoplay/presentation/controllers/autoplay_queue_controller.dart';
import 'package:flow_music/features/autoplay/presentation/widgets/now_playing_queue_view.dart';
import 'package:flow_music/features/favorites/presentation/controllers/favorites_controller.dart';
import 'package:flow_music/features/home/presentation/controllers/home_view_controller.dart';
import 'package:flow_music/features/library/data/downloaded_audio.dart';
import 'package:flow_music/features/library/presentation/widgets/downloaded_file_actions.dart';
import 'package:flow_music/features/playlists/presentation/controllers/playlists_controller.dart';
import 'package:flow_music/features/playlists/presentation/widgets/playlist_actions.dart';
import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/features/sleep_timer/presentation/controllers/sleep_timer_controller.dart';
import 'package:flow_music/features/song/presentation/controllers/song_controller.dart';
import 'package:flow_music/features/song/presentation/widgets/share_song_sheet.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Acciones imperativas del app bar de home.
class HomeAppBarActionController {
  final WidgetRef ref;

  const HomeAppBarActionController({required this.ref});

  void handleBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      ref.read(homeViewProvider.notifier).back();
    }
  }

  void openDrawer(BuildContext context) {
    Scaffold.of(context).openDrawer();
  }

  void clearSearch({
    required TextEditingController searchController,
    required FocusNode focusNode,
    required Function(String)? onQuery,
  }) {
    searchController.clear();
    onQuery?.call('');
    focusNode.requestFocus();
  }

  Future<void> addToPlaylist({
    required BuildContext context,
    required DownloadedAudio audio,
  }) {
    return showAddToPlaylistFlow(context: context, ref: ref, audio: audio);
  }

  Future<void> handleNowPlayingMenuAction({
    required BuildContext context,
    required HomeAppBarMenuAction action,
    required DownloadedAudio item,
  }) async {
    switch (action) {
      case HomeAppBarMenuAction.toggleVideo:
        final controller = ref.read(songController);
        return controller.switchMode(
          controller.currentMode == PlaybackMode.video
              ? PlaybackMode.audio
              : PlaybackMode.video,
        );
      case HomeAppBarMenuAction.favorite:
        if (item.videoId.isEmpty) return;
        final added = await ref
            .read(favoritesControllerProvider.notifier)
            .toggle(
              videoId: item.videoId,
              title: item.title,
              author: item.author,
              thumbnailUrl: item.thumbnailUrl,
            );
        if (!context.mounted) return;
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              added
                  ? LocaleKeys.added_to_favorites.tr()
                  : LocaleKeys.removed_from_favorites.tr(),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      case HomeAppBarMenuAction.queue:
        return showNowPlayingQueueSheet(context: context, ref: ref);
      case HomeAppBarMenuAction.share:
        return showShareSongSheet(context: context, ref: ref);
      case HomeAppBarMenuAction.addToPlaylist:
        return addToPlaylist(context: context, audio: item);
      case HomeAppBarMenuAction.sleepTimer:
        return _showAppBarSleepTimerSheet(
          context: context,
          state: ref.read(sleepTimerControllerProvider),
          controller: ref.read(sleepTimerControllerProvider.notifier),
        );
      case HomeAppBarMenuAction.audioTools:
        return _showAppBarAudioToolsSheet(
          context: context,
          state: ref.read(audioToolsControllerProvider),
          controller: ref.read(audioToolsControllerProvider.notifier),
        );
      case HomeAppBarMenuAction.download:
        final controller = ref.read(songController);
        if (controller.hasDownloadedCurrentMedia) {
          return showDownloadedFileActions(
            context: context,
            audio: controller.currentDownloadedMedia,
          );
        } else {
          return controller.downloadCurrentMedia();
        }
      case HomeAppBarMenuAction.offline:
        final controller = ref.read(songController);
        if (controller.hasOfflineCurrentAudio) {
          return controller.removeCurrentOfflineAudio();
        } else {
          return controller.saveCurrentAudioForOffline();
        }
    }
  }
}

enum HomeAppBarMenuAction {
  toggleVideo,
  favorite,
  queue,
  share,
  addToPlaylist,
  sleepTimer,
  audioTools,
  download,
  offline,
}

Future<void> showNowPlayingQueueSheet({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final notifier = ref.read(autoplayQueueControllerProvider.notifier);

  Future<void> playFromQueue(NextTrack? track) async {
    if (track == null) return;
    final controller = ref.read(songController);
    if (controller.currentMode == PlaybackMode.video) {
      await controller.playVideo(id: track.suggestion.videoId);
      return;
    }
    final resolved = track.resolved;
    if (resolved != null) {
      await controller.playPrefetched(resolved);
    } else {
      await controller.playAudio(id: track.suggestion.videoId);
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(autoplayQueueControllerProvider);
          final theme = Theme.of(context);
          final upcoming = state.upcoming;
          return SafeArea(
            child: FractionallySizedBox(
              heightFactor: 0.78,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            LocaleKeys.up_next.tr(),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: upcoming.isEmpty
                              ? null
                              : () async {
                                  final playlist = await showCreatePlaylistFlow(
                                    context: context,
                                    ref: ref,
                                  );
                                  if (playlist == null) return;
                                  final playlistController = ref.read(
                                    playlistsControllerProvider.notifier,
                                  );
                                  for (final suggestion in [
                                    if (state.current != null) state.current!,
                                    ...upcoming,
                                  ]) {
                                    await playlistController.addItem(
                                      playlist.id,
                                      _appBarSuggestionToAudio(suggestion),
                                    );
                                  }
                                  if (context.mounted) {
                                    ScaffoldMessenger.maybeOf(
                                      context,
                                    )?.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          LocaleKeys.playlist_added.tr(),
                                        ),
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.save_alt_rounded),
                          label: Text(LocaleKeys.save_as_playlist.tr()),
                        ),
                        IconButton(
                          tooltip: LocaleKeys.clear.tr(),
                          onPressed: upcoming.isEmpty
                              ? null
                              : notifier.clearUpcoming,
                          icon: const Icon(Icons.clear_all_rounded),
                        ),
                      ],
                    ),
                  ),
                  if (state.isLoadingMore)
                    const LinearProgressIndicator(minHeight: 2),
                  Expanded(
                    child: NowPlayingQueueView(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
                      onPlay: playFromQueue,
                      onTrackSelected: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

DownloadedAudio _appBarSuggestionToAudio(YouTubeSearchSuggestion suggestion) {
  return DownloadedAudio(
    videoId: suggestion.videoId,
    title: suggestion.displayText,
    author: suggestion.channelTitle,
    thumbnailUrl: suggestion.thumbnailUrl,
    filePath: '',
    downloadedAt: DateTime.now(),
  );
}

Future<void> _showAppBarSleepTimerSheet({
  required BuildContext context,
  required SleepTimerState state,
  required SleepTimerController controller,
}) async {
  final remaining = state.remaining;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(
              LocaleKeys.sleep_timer.tr(),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (remaining != null) ...[
              const SizedBox(height: 8),
              Text(
                LocaleKeys.sleep_timer_remaining.tr(
                  args: [remaining.inMinutes.toString()],
                ),
              ),
            ],
            for (final minutes in const [15, 30, 45, 60])
              ListTile(
                leading: const Icon(Icons.timer_rounded),
                title: Text(
                  LocaleKeys.minutes_count.tr(args: [minutes.toString()]),
                ),
                onTap: () {
                  controller.start(Duration(minutes: minutes));
                  Navigator.of(context).pop();
                },
              ),
            if (state.isActive)
              ListTile(
                leading: const Icon(Icons.timer_off_rounded),
                title: Text(LocaleKeys.cancel_sleep_timer.tr()),
                onTap: () {
                  controller.cancel();
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      );
    },
  );
}

Future<void> _showAppBarAudioToolsSheet({
  required BuildContext context,
  required AudioToolsState state,
  required AudioToolsController controller,
}) async {
  var rate = state.playbackRate;
  var normalize = state.normalizeVolume;
  var smooth = state.smoothTransitions;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final theme = Theme.of(context);
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                Text(
                  LocaleKeys.audio_tools.tr(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${LocaleKeys.playback_rate.tr()}: ${rate.toStringAsFixed(2)}x',
                ),
                Slider(
                  min: 0.5,
                  max: 2,
                  divisions: 6,
                  value: rate,
                  label: '${rate.toStringAsFixed(2)}x',
                  onChanged: (value) {
                    setSheetState(() => rate = value);
                    controller.setPlaybackRate(value);
                  },
                ),
                SwitchListTile.adaptive(
                  value: normalize,
                  onChanged: (value) {
                    setSheetState(() => normalize = value);
                    controller.setNormalizeVolume(value);
                  },
                  title: Text(LocaleKeys.normalize_volume.tr()),
                  secondary: const Icon(Icons.volume_up_rounded),
                ),
                SwitchListTile.adaptive(
                  value: smooth,
                  onChanged: (value) {
                    setSheetState(() => smooth = value);
                    controller.setSmoothTransitions(value);
                  },
                  title: Text(LocaleKeys.smooth_transitions.tr()),
                  secondary: const Icon(Icons.blur_on_rounded),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
