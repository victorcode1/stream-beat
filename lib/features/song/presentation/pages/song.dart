import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/adaptive_layout.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/audio_tools/presentation/controllers/audio_tools_controller.dart';
import 'package:flow_music/features/autoplay/presentation/controllers/autoplay_queue_controller.dart';
import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/features/autoplay/presentation/widgets/now_playing_queue_view.dart';
import 'package:flow_music/features/favorites/presentation/controllers/favorites_controller.dart';
import 'package:flow_music/features/home/presentation/controllers/home_app_bar_action_controller.dart';
import 'package:flow_music/features/home/presentation/providers/desktop_queue_rail.dart';
import 'package:flow_music/features/settings/presentation/controllers/default_playback_mode_controller.dart';
import 'package:flow_music/features/song/presentation/controllers/repeat_mode_controller.dart';
import 'package:flow_music/features/song/presentation/controllers/song_controller.dart';
import 'package:flow_music/features/song/presentation/controllers/song_page_controller.dart';
import 'package:flow_music/features/song/presentation/widgets/modern_player_hero.dart';
import 'package:flow_music/features/song/presentation/widgets/modern_player_widget.dart';
import 'package:flow_music/features/song/presentation/widgets/share_song_sheet.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SongWidget extends ConsumerStatefulWidget {
  final Map<String?, String?> data;

  /// Cuando es `true`, el reproductor se abrio fuera del shell `HomePage`
  /// (p.ej. empujado con `Navigator.push` desde la biblioteca o una playlist),
  /// por lo que no hay `AppAbarMain` arriba. En ese caso `ScreenPlay` dibuja su
  /// propio boton de retroceso y el titulo en el app bar para no quedar sin
  /// cabecera ni navegacion.
  final bool standalone;
  const SongWidget({super.key, required this.data, this.standalone = false});

  static const SongPageController pageController = SongPageController();

  @override
  ConsumerState<SongWidget> createState() => _PlaySongState();
}

class _PlaySongState extends ConsumerState<SongWidget> {
  @override
  void initState() {
    debugPrint('Initializing SongWidget with data: ${widget.data}');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final playListId = widget.data['playListId'];
    final controller = ref.watch(songController);
    SongWidget.pageController.configurePlaylist(
      controller: controller,
      playlistId: playListId,
    );
    final args = SongWidget.pageController.resolveArgs(
      data: widget.data,
      controller: controller,
    );

    if (args == null) {
      return Center(child: Text(LocaleKeys.no_id_song.tr()));
    }

    return ScreenPlay(
      key: ValueKey(args.id),
      id: args.id,
      initialMode: args.initialMode,
      initialDuration: args.initialDuration,
      standalone: widget.standalone,
    );
  }
}

class ScreenPlay extends ConsumerStatefulWidget {
  final String id;
  final PlaybackMode? initialMode;
  final Duration? initialDuration;
  final bool standalone;
  const ScreenPlay({
    super.key,
    required this.id,
    this.initialMode,
    this.initialDuration,
    this.standalone = false,
  });

  @override
  ConsumerState<ScreenPlay> createState() => _ScreenPlayState();
}

class _ScreenPlayState extends ConsumerState<ScreenPlay>
    with AutomaticKeepAliveClientMixin<ScreenPlay> {
  @override
  void initState() {
    super.initState();
    _schedulePlaybackInitialization();
  }

  @override
  void didUpdateWidget(covariant ScreenPlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id ||
        oldWidget.initialMode != widget.initialMode ||
        oldWidget.initialDuration != widget.initialDuration) {
      _schedulePlaybackInitialization();
    }
  }

  void _schedulePlaybackInitialization() {
    final requestedId = widget.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.id != requestedId) return;
      SongWidget.pageController.initializePlayback(
        controller: ref.read(songController),
        id: requestedId,
        initialMode: widget.initialMode,
        defaultMode: ref.read(defaultPlaybackModeControllerProvider),
        initialDuration: widget.initialDuration,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = ref.watch(songController);
    final autoplayQueue = ref.watch(autoplayQueueControllerProvider);
    final autoplayNotifier = ref.read(autoplayQueueControllerProvider.notifier);
    final repeatEnabled = ref.watch(repeatModeControllerProvider);
    final repeatNotifier = ref.read(repeatModeControllerProvider.notifier);
    final audioTools = ref.watch(audioToolsControllerProvider);
    final audioToolsNotifier = ref.read(audioToolsControllerProvider.notifier);
    final currentVideoId = controller.currentVideoId ?? widget.id;
    final favorites = ref.watch(favoritesControllerProvider);
    final isFavorite = favorites.any(
      (favorite) => favorite.videoId == currentVideoId,
    );

    final theme = Theme.of(context);
    final isDesktop = useFlowDesktopShell(context);
    final page = Scaffold(
      backgroundColor: Colors.transparent,
      // Igual al mockup: el reproductor inmersivo no lleva toggle Audio/Video
      // arriba (el chip "Video" del pie cubre el cambio de modo). En el shell la
      // cabecera "REPRODUCIENDO" ya viene del app bar de home; solo en modo
      // standalone dibujamos un app bar propio con el boton de retroceso.
      appBar: widget.standalone
          ? AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: theme.colorScheme.onSurface,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            )
          : null,
      body: Column(
        children: [
          Expanded(
            child: ModernPlayerWidget(
              audioPlayer: controller.audioPlayer,
              videoController: controller.videoPlayerController,
              webEmbedVideoId: controller.webEmbedVideoId,
              currentVideoId: currentVideoId,
              videoTitle: controller.displayTitle,
              videoAuthor: controller.displayAuthor,
              thumbnailUrl: controller.displayThumbnailUrl,
              isLoading: controller.isLoading,
              isFavorite: isFavorite,
              onToggleFavorite: currentVideoId.isEmpty
                  ? null
                  : () => _toggleFavorite(
                      context: context,
                      videoId: currentVideoId,
                      title: controller.displayTitle ?? currentVideoId,
                      author: controller.displayAuthor ?? '',
                      thumbnailUrl: controller.displayThumbnailUrl ?? '',
                    ),
              onPrevious: autoplayQueue.hasPrevious
                  ? () => SongWidget.pageController.playFromQueue(
                      controller: controller,
                      track: autoplayNotifier.playPrevious(),
                    )
                  : null,
              onNext: autoplayQueue.hasNext
                  ? () async => SongWidget.pageController.playFromQueue(
                      controller: controller,
                      track: await autoplayNotifier.playNext(),
                    )
                  : null,
              repeatEnabled: repeatEnabled,
              onToggleRepeat: repeatNotifier.toggle,
              onShuffle: autoplayQueue.upcoming.length > 1
                  ? autoplayNotifier.shuffleUpcoming
                  : null,
              playbackRate: audioTools.playbackRate,
              normalizeVolume: audioTools.normalizeVolume,
              smoothTransitions: audioTools.smoothTransitions,
              onPlaybackRateChanged: audioToolsNotifier.setPlaybackRate,
              onNormalizeVolumeChanged: audioToolsNotifier.setNormalizeVolume,
              onSmoothTransitionsChanged:
                  audioToolsNotifier.setSmoothTransitions,
              // En escritorio el reproductor inmersivo muestra la cola a la
              // derecha.
              sourceLabel: isDesktop ? LocaleKeys.playing.tr() : null,
              // El boton de cola de la barra superior pliega el riel.
              sideRail: isDesktop && ref.watch(desktopQueueRailVisibleProvider)
                  ? const _PlayerQueueRail()
                  : null,
              // En escritorio los chips del pie no se dibujan, asi que el
              // cambio a video y la cola viven en los controles del
              // reproductor (mockup "Escritorio · Reproduciendo").
              isVideo: controller.currentMode == PlaybackMode.video,
              onToggleVideo: isDesktop
                  ? () => controller.switchMode(
                      controller.currentMode == PlaybackMode.video
                          ? PlaybackMode.audio
                          : PlaybackMode.video,
                    )
                  : null,
              onToggleQueue: isDesktop
                  ? ref.read(desktopQueueRailVisibleProvider.notifier).toggle
                  : null,
            ),
          ),
          // Los accesos Video / Cola / Compartir viven en la barra superior
          // del shell; solo la pantalla suelta (sin shell) los lleva al pie.
          if (!isDesktop && widget.standalone)
            _PlayerActionChips(
              isVideo: controller.currentMode == PlaybackMode.video,
              onToggleVideo: () => controller.switchMode(
                controller.currentMode == PlaybackMode.video
                    ? PlaybackMode.audio
                    : PlaybackMode.video,
              ),
              onQueue: () =>
                  showNowPlayingQueueSheet(context: context, ref: ref),
              onShare: () => showShareSongSheet(context: context, ref: ref),
            ),
        ],
      ),
    );

    if (isDesktop) return page;
    // En movil la pantalla toma el color de la cancion: la caratula
    // desenfocada cubre todo el fondo, incluidos los accesos del pie, y el
    // texto pasa a claro para leerse encima.
    return Theme(
      data: playerOnDarkTheme(theme),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PlayerAmbientBackground(thumbnailUrl: controller.displayThumbnailUrl),
          page,
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _toggleFavorite({
    required BuildContext context,
    required String videoId,
    required String title,
    required String author,
    required String thumbnailUrl,
  }) async {
    if (videoId.isEmpty) return;
    final added = await ref
        .read(favoritesControllerProvider.notifier)
        .toggle(
          videoId: videoId,
          title: title,
          author: author,
          thumbnailUrl: thumbnailUrl,
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
  }
}

/// Fila de accesos rapidos al pie del reproductor: Video / Cola / Compartir.
class _PlayerActionChips extends StatelessWidget {
  const _PlayerActionChips({
    required this.isVideo,
    required this.onToggleVideo,
    required this.onQueue,
    required this.onShare,
  });

  final bool isVideo;
  final VoidCallback onToggleVideo;
  final VoidCallback onQueue;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _PlayerActionChip(
              icon: isVideo ? Icons.videocam_rounded : Icons.videocam_outlined,
              label: LocaleKeys.video.tr(),
              selected: isVideo,
              onTap: onToggleVideo,
            ),
            _PlayerActionChip(
              icon: Icons.queue_music_rounded,
              label: LocaleKeys.queue.tr(),
              onTap: onQueue,
            ),
            _PlayerActionChip(
              icon: Icons.ios_share_rounded,
              label: LocaleKeys.share.tr(),
              onTap: onShare,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerActionChip extends StatelessWidget {
  const _PlayerActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = selected ? colors.primary : colors.onSurfaceVariant;

    return Material(
      color: selected
          ? colors.primary.withValues(alpha: 0.14)
          : colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Riel derecho del reproductor en escritorio con la cola de reproducción.
class _PlayerQueueRail extends ConsumerWidget {
  const _PlayerQueueRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final controller = ref.watch(songController);

    // Respaldo para la fila "sonando" cuando la canción se abrió sin cola
    // (favoritos, enlace directo…) y el autoplay todavía no la sembró.
    final fallbackTitle = controller.displayTitle ?? '';
    final currentFallback = fallbackTitle.isEmpty
        ? null
        : YouTubeSearchSuggestion(
            videoId: controller.currentVideoId ?? '',
            displayText: fallbackTitle,
            channelTitle: controller.displayAuthor ?? '',
            thumbnailUrl: controller.displayThumbnailUrl ?? '',
          );

    return SafeArea(
      left: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera del mockup: el titulo se apoya en el borde inferior del
          // riel con un subrayado de acento, en vez de flotar sobre una linea
          // gris suelta.
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.outlineVariant)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: colors.primary, width: 2),
                      ),
                    ),
                    child: Text(
                      LocaleKeys.up_next.tr(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: NowPlayingQueueView(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 18),
              reorderable: false,
              currentFallback: currentFallback,
              onPlay: (track) => SongWidget.pageController.playFromQueue(
                controller: ref.read(songController),
                track: track,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
