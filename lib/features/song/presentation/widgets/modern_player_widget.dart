import 'package:flow_music/core/audio/flow_player.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/theme/custom_theme.dart';
import 'package:flow_music/core/utils/adaptive_layout.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../controllers/modern_player_view_controller.dart';
import '../controllers/modern_player_view_state.dart';
import 'modern_player_artwork.dart';
import 'modern_player_controls.dart';
import 'modern_player_hero.dart';
import 'modern_player_media_display.dart';
import 'modern_player_wide_layout.dart';

/// Vista del reproductor moderno.
///
/// Solo compone layout y delega estado y comandos al controller de presentacion.
class ModernPlayerWidget extends StatefulWidget {
  final FlowPlayer audioPlayer;
  final VideoPlayerController? videoController;
  final String? webEmbedVideoId;
  final String? currentVideoId;
  final String? videoTitle;
  final String? videoAuthor;
  final String? thumbnailUrl;
  final bool isLoading;
  final bool isDownloading;
  final bool isSavingOffline;
  final bool isAudioDownloaded;
  final bool isOfflineSaved;
  final double downloadProgress;
  final double offlineProgress;
  final String? downloadLabel;
  final Future<void> Function()? onDownloadPressed;
  final Future<void> Function()? onDownloadedFilePressed;
  final Future<void> Function()? onSaveOfflinePressed;
  final Future<void> Function()? onRemoveOfflinePressed;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool repeatEnabled;
  final VoidCallback? onToggleRepeat;
  final VoidCallback? onShuffle;
  final double playbackRate;
  final bool normalizeVolume;
  final bool smoothTransitions;
  final ValueChanged<double>? onPlaybackRateChanged;
  final ValueChanged<bool>? onNormalizeVolumeChanged;
  final ValueChanged<bool>? onSmoothTransitionsChanged;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  /// Riel derecho (cola/letra) que se muestra solo en la variante de escritorio.
  final Widget? sideRail;

  /// Reproduciendo el video en vez del audio, para el selector de escritorio.
  final bool isVideo;

  /// Alterna audio/video. Null oculta el selector.
  final VoidCallback? onToggleVideo;

  /// Pliega o abre el riel de cola desde los controles del reproductor.
  final VoidCallback? onToggleQueue;

  /// Etiqueta de origen ("Reproduciendo desde…") para el escritorio.
  final String? sourceLabel;

  const ModernPlayerWidget({
    super.key,
    required this.audioPlayer,
    this.videoController,
    this.webEmbedVideoId,
    this.currentVideoId,
    this.videoTitle,
    this.videoAuthor,
    this.thumbnailUrl,
    this.isLoading = false,
    this.isDownloading = false,
    this.isSavingOffline = false,
    this.isAudioDownloaded = false,
    this.isOfflineSaved = false,
    this.downloadProgress = 0,
    this.offlineProgress = 0,
    this.downloadLabel,
    this.onDownloadPressed,
    this.onDownloadedFilePressed,
    this.onSaveOfflinePressed,
    this.onRemoveOfflinePressed,
    this.onPrevious,
    this.onNext,
    this.repeatEnabled = false,
    this.onToggleRepeat,
    this.onShuffle,
    this.playbackRate = 1,
    this.normalizeVolume = false,
    this.smoothTransitions = false,
    this.onPlaybackRateChanged,
    this.onNormalizeVolumeChanged,
    this.onSmoothTransitionsChanged,
    this.isFavorite = false,
    this.onToggleFavorite,
    this.sideRail,
    this.isVideo = false,
    this.onToggleVideo,
    this.onToggleQueue,
    this.sourceLabel,
  });

  @override
  State<ModernPlayerWidget> createState() => _ModernPlayerWidgetState();
}

class _ModernPlayerWidgetState extends State<ModernPlayerWidget> {
  late final ModernPlayerViewController _controller;

  /// Sentido del ultimo salto en la cola, para que la animacion de relevo se
  /// mueva igual que el gesto: "siguiente" entra por la derecha y "anterior"
  /// por la izquierda. El avance automatico al terminar la cancion cuenta como
  /// "siguiente".
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    _controller = ModernPlayerViewController(
      audioPlayer: widget.audioPlayer,
      videoController: widget.videoController,
      currentVideoId: widget.currentVideoId,
      playbackRate: widget.playbackRate,
      normalizeVolume: widget.normalizeVolume,
    );
  }

  @override
  void didUpdateWidget(covariant ModernPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.syncWith(
      videoController: widget.videoController,
      currentVideoId: widget.currentVideoId,
      playbackRate: widget.playbackRate,
      normalizeVolume: widget.normalizeVolume,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Anota el sentido antes de delegar en el callback real. No hace falta
  /// `setState`: el cambio de cancion ya provoca la reconstruccion, y es ahi
  /// donde se lee el sentido.
  VoidCallback? _tracking(VoidCallback? action, {required bool forward}) {
    if (action == null) return null;
    return () {
      _forward = forward;
      action();
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final extras = theme.extension<FlowThemeExtras>();
    final usesWebEmbed = kIsWeb && widget.webEmbedVideoId != null;
    final trackKey =
        widget.currentVideoId ?? widget.thumbnailUrl ?? widget.videoTitle ?? '';
    // Al cambiar de cancion el reproductor pasa por "cargando" un instante.
    // Vaciar la pantalla en ese momento era el brinco: mientras haya datos de
    // la pista, se mantiene el reproductor y solo se atenua la caratula. La
    // pantalla completa de carga queda para el arranque en frio.
    final hasTrackToShow =
        (widget.videoTitle ?? '').isNotEmpty ||
        (widget.thumbnailUrl ?? '').isNotEmpty;
    final showColdLoader = widget.isLoading && !hasTrackToShow;
    final isBusy = widget.isLoading && hasTrackToShow;

    return ValueListenableBuilder<ModernPlayerViewState>(
      valueListenable: _controller,
      builder: (context, playerState, _) {
        final controls = ModernPlayerControls(
          theme: theme,
          isDark: isDark,
          title: widget.videoTitle,
          author: widget.videoAuthor,
          isFavorite: widget.isFavorite,
          onToggleFavorite: widget.onToggleFavorite,
          effectiveDuration: playerState.effectiveDuration,
          position: playerState.position,
          isPlaying: playerState.isPlaying,
          isMuted: playerState.isMuted,
          volume: playerState.volume,
          onTogglePlayPause: _controller.togglePlayPause,
          onSeek: _controller.seekTo,
          onSkipBackward: () => _controller.skip(-10),
          onSkipForward: () => _controller.skip(10),
          onToggleMute: _controller.toggleMute,
          onVolumeChanged: _controller.setVolume,
          onPrevious: _tracking(widget.onPrevious, forward: false),
          onNext: _tracking(widget.onNext, forward: true),
          repeatEnabled: widget.repeatEnabled,
          onToggleRepeat: widget.onToggleRepeat,
          onShuffle: widget.onShuffle,
          trackKey: trackKey,
          forward: _forward,
          // El reproductor de escritorio suma el selector Audio/Video, la
          // velocidad y el volumen (mockup "Escritorio · Reproduciendo").
          wide: useFlowDesktopShell(context),
          isVideo: widget.isVideo,
          onToggleVideo: widget.onToggleVideo,
          onToggleQueue: widget.onToggleQueue,
          playbackRate: widget.playbackRate,
          onCyclePlaybackRate: widget.onPlaybackRateChanged == null
              ? null
              : () => widget.onPlaybackRateChanged!(
                  _nextPlaybackRate(widget.playbackRate),
                ),
        );

        if (useFlowDesktopShell(context)) {
          return ModernPlayerWideLayout(
            theme: theme,
            isDark: isDark,
            backgroundGradient: extras?.secondaryGradient,
            backgroundColor: extras == null ? theme.colorScheme.surface : null,
            isLoading: showColdLoader,
            isBusy: isBusy,
            webEmbedVideoId: widget.webEmbedVideoId,
            videoTitle: widget.videoTitle,
            videoAuthor: widget.videoAuthor,
            thumbnailUrl: widget.thumbnailUrl,
            videoController: widget.videoController,
            controls: controls,
            sideRail: widget.sideRail,
            sourceLabel: widget.sourceLabel,
            trackKey: trackKey,
            forward: _forward,
          );
        }

        // En movil, sin video, la caratula ocupa la parte de arriba de borde a
        // borde y se funde con el fondo ambiental que pinta la pagina, como
        // en Shazam. El video y el embed web conservan su presentacion.
        // Alto de la barra superior cuando el cuerpo se dibuja detras de ella.
        final topInset = MediaQuery.paddingOf(context).top;
        final showsHero =
            !usesWebEmbed &&
            !showColdLoader &&
            !(widget.videoController?.value.isInitialized ?? false);
        if (showsHero) {
          return Column(
            key: const ValueKey('modern-player-hero'),
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      // La caratula arranca en el borde superior, por detras
                      // de la barra: se suma ese alto para no recortarla.
                      height: constraints.maxHeight.clamp(
                        0.0,
                        constraints.maxWidth * 1.05 + topInset,
                      ),
                      child: ModernPlayerHero(
                        thumbnailUrl: widget.thumbnailUrl,
                        trackKey: trackKey,
                        forward: _forward,
                        isBusy: isBusy,
                        topInset: topInset,
                        placeholder: ModernPlayerArtwork(
                          theme: theme,
                          borderRadius: 0,
                          elevated: false,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              controls,
            ],
          );
        }

        // El video y el cargador no van detras de la barra superior.
        return Padding(
          padding: EdgeInsets.only(top: topInset),
          child: Container(
            decoration: BoxDecoration(
              gradient: extras?.secondaryGradient,
              color: extras == null ? theme.colorScheme.surface : null,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              layoutBuilder: (currentChild, previousChildren) => Stack(
                fit: StackFit.expand,
                children: [...previousChildren, ?currentChild],
              ),
              child: showColdLoader
                  ? Center(
                      key: const ValueKey('modern-player-cold-loader'),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: theme.colorScheme.primary,
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            LocaleKeys.loading.tr(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      key: const ValueKey('modern-player-content'),
                      children: [
                        Expanded(
                          child: ModernPlayerMediaDisplay(
                            theme: theme,
                            webEmbedVideoId: widget.webEmbedVideoId,
                            videoController: widget.videoController,
                            thumbnailUrl: widget.thumbnailUrl,
                            trackKey: trackKey,
                            forward: _forward,
                            isBusy: isBusy,
                          ),
                        ),
                        if (!usesWebEmbed) controls,
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// Siguiente velocidad del ciclo del boton `1.0×`.
///
/// Son los mismos pasos que ofrece el selector de velocidad de ajustes, para
/// que ambos controles hablen el mismo idioma.
double _nextPlaybackRate(double current) {
  const steps = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  for (final step in steps) {
    if (step > current + 0.01) return step;
  }
  return steps.first;
}
