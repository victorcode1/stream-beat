import 'package:easy_localization/easy_localization.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flow_music/core/audio/background_audio_handler.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/radio/presentation/controllers/radio_queue_controller.dart';
import 'package:flow_music/features/radio/presentation/utils/play_radio_station.dart';
import 'package:flow_music/shared/widgets/optimized_network_image.dart';
import 'package:flow_music/shared/widgets/playing_bars_indicator.dart';
import 'package:flow_music/shared/widgets/style_contour.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Barra compacta para la emisora que suena en segundo plano.
class RadioMiniPlayer extends ConsumerWidget {
  const RadioMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<MediaItem?>(
      stream: flowAudioHandler.mediaItem,
      initialData: flowAudioHandler.mediaItem.value,
      builder: (context, snapshot) {
        final item = snapshot.data;
        if (item == null ||
            item.title.trim().isEmpty ||
            item.title == 'StreamBeat') {
          return const SizedBox.shrink();
        }
        final queue = ref.watch(radioQueueControllerProvider);
        final colors = Theme.of(context).colorScheme;
        return StreamBuilder<PlaybackState>(
          stream: flowAudioHandler.playbackState,
          initialData: flowAudioHandler.playbackState.value,
          builder: (context, playbackSnapshot) {
            final playback =
                playbackSnapshot.data ?? flowAudioHandler.playbackState.value;
            final isLoading = isRadioPlaybackLoading(playback.processingState);
            final hasError =
                playback.processingState == AudioProcessingState.error;
            final isPlaying = playback.playing && !isLoading;

            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              // En Mola, lo que suena lleva sus contornos de tela alrededor.
              child: StyleContour(
                radius: 18,
                strokeWidth: 1.5,
                gap: 2,
                maxRings: 2,
                child: Material(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.push('/radio-player'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          _Artwork(
                            artUri: item.artUri,
                            isPlaying: isPlaying && !hasError,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  hasError
                                      ? LocaleKeys.radio_play_interrupted.tr()
                                      : item.artist ?? 'Radio en directo',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: LocaleKeys.previous.tr(),
                            onPressed: !isLoading && queue.hasPrevious
                                ? () => playPreviousRadioStation(
                                    context: context,
                                    ref: ref,
                                  )
                                : null,
                            icon: const Icon(Icons.skip_previous_rounded),
                          ),
                          RadioMiniPlayerPrimaryControl(
                            isLoading: isLoading,
                            isPlaying: isPlaying,
                            tooltip: isLoading
                                ? LocaleKeys.loading.tr()
                                : hasError
                                ? LocaleKeys.retry.tr()
                                : isPlaying
                                ? LocaleKeys.pause.tr()
                                : LocaleKeys.play.tr(),
                            onPressed: isLoading
                                ? null
                                : () => isPlaying
                                      ? flowAudioHandler.pause()
                                      : flowAudioHandler.play(),
                          ),
                          IconButton(
                            tooltip: LocaleKeys.next.tr(),
                            onPressed: !isLoading && queue.hasNext
                                ? () => playNextRadioStation(
                                    context: context,
                                    ref: ref,
                                  )
                                : null,
                            icon: const Icon(Icons.skip_next_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Covers both states in which the audio service has not produced sound yet.
bool isRadioPlaybackLoading(AudioProcessingState processingState) =>
    processingState == AudioProcessingState.loading ||
    processingState == AudioProcessingState.buffering;

/// Fixed-size primary action used by the mini player.
///
/// Keeping this as a small independent widget makes the loading transition
/// testable without initializing the native audio platform in widget tests.
class RadioMiniPlayerPrimaryControl extends StatelessWidget {
  const RadioMiniPlayerPrimaryControl({
    required this.isLoading,
    required this.isPlaying,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final bool isLoading;
  final bool isPlaying;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return IconButton.filled(
      key: const Key('radio-mini-player-primary-control'),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        disabledBackgroundColor: colors.primary,
        disabledForegroundColor: colors.onPrimary,
      ),
      onPressed: onPressed,
      icon: isLoading
          ? SizedBox.square(
              key: const Key('radio-mini-player-loading-indicator'),
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colors.onPrimary,
              ),
            )
          : Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.artUri, required this.isPlaying});

  final Uri? artUri;

  /// Superpone las barras animadas mientras la emisora suena.
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.square(
        dimension: 44,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _image(context),
            AnimatedOpacity(
              opacity: isPlaying ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.42),
                child: Center(
                  child: PlayingBarsIndicator(
                    isPlaying: isPlaying,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _image(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 44,
      child: artUri == null
          ? ColoredBox(
              color: colors.primary.withValues(alpha: 0.16),
              child: Icon(Icons.radio_rounded, color: colors.primary),
            )
          : OptimizedNetworkImage(
              url: artUri.toString(),
              displaySize: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(
                color: colors.primary.withValues(alpha: 0.16),
                child: Icon(Icons.radio_rounded, color: colors.primary),
              ),
            ),
    );
  }
}
