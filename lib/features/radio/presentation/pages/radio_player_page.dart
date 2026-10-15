import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/audio/background_audio_handler.dart';
import 'package:flow_music/core/sharing/station_share_service.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/flow_mix/presentation/controllers/flow_mix_controller.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/presentation/controllers/radio_favorites_controller.dart';
import 'package:flow_music/features/radio/presentation/controllers/radio_queue_controller.dart';
import 'package:flow_music/features/radio/presentation/utils/play_radio_station.dart';
import 'package:flow_music/features/radio/presentation/widgets/radio_playlist_actions.dart';
import 'package:flow_music/features/radio/presentation/widgets/station_links.dart';
import 'package:flow_music/shared/widgets/optimized_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Reproductor grande de emisoras, equivalente a la pantalla de cancion.
///
/// Muestra la portada, el nombre y los datos de la emisora actual y permite
/// pausar / reanudar, pasar a la siguiente / anterior emisora de la cola y
/// marcarla como favorita. Conserva su propio `Scaffold` + `AppBar`, pero se
/// renderiza dentro del shell `HomePage` para mantener visible la navegacion
/// principal.
class RadioPlayerPage extends ConsumerStatefulWidget {
  const RadioPlayerPage({super.key, this.initialStation});

  final RadioStation? initialStation;

  @override
  ConsumerState<RadioPlayerPage> createState() => _RadioPlayerPageState();
}

class _RadioPlayerPageState extends ConsumerState<RadioPlayerPage> {
  @override
  void initState() {
    super.initState();
    final station = widget.initialStation;
    if (station == null) return;
    ref.read(radioQueueControllerProvider.notifier).enqueue([station], 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(playRadioStation(context: context, ref: ref, station: station));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final radioQueue = ref.watch(radioQueueControllerProvider);
    final flowMix = ref.watch(flowMixControllerProvider);
    final station = radioQueue.current;
    final appBarTitle =
        station?.name ?? flowAudioHandler.mediaItem.value?.title ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          appBarTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          if (station != null) ...[
            Builder(
              builder: (shareContext) => IconButton(
                tooltip: LocaleKeys.share_station.tr(),
                icon: Icon(Icons.share_rounded, color: colors.onSurface),
                onPressed: () => ref
                    .read(stationShareServiceProvider)
                    .shareStation(
                      originContext: shareContext,
                      station: station,
                    ),
              ),
            ),
            IconButton(
              tooltip: LocaleKeys.add_to_playlist.tr(),
              icon: Icon(Icons.playlist_add_rounded, color: colors.onSurface),
              onPressed: () => showAddToRadioPlaylistFlow(
                context: context,
                ref: ref,
                station: station,
              ),
            ),
            _FavoriteStationButton(station: station),
            StationActionsMenu(station: station),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<MediaItem?>(
        stream: flowAudioHandler.mediaItem,
        builder: (context, snapshot) {
          final item = snapshot.data;
          final title = item?.title ?? station?.name ?? '';
          final subtitle = item?.artist ?? _stationSubtitle(station);
          final artUri = item?.artUri?.toString() ?? station?.artworkUrl ?? '';

          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(),
                  _Artwork(artUri: artUri, colors: colors),
                  const SizedBox(height: 36),
                  Text(
                    title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LiveBadge(colors: colors),
                      if (station != null &&
                          flowMix.ownsQueue(radioQueue.stations) &&
                          flowMix.contains(station)) ...[
                        const SizedBox(width: 8),
                        _FlowMixFeedbackButton(
                          station: station,
                          hasNext: radioQueue.hasNext,
                        ),
                      ],
                    ],
                  ),
                  const Spacer(),
                  _Controls(
                    hasNext: radioQueue.hasNext,
                    hasPrevious: radioQueue.hasPrevious,
                    onNext: radioQueue.hasNext
                        ? () => playNextRadioStation(context: context, ref: ref)
                        : null,
                    onPrevious: radioQueue.hasPrevious
                        ? () => playPreviousRadioStation(
                            context: context,
                            ref: ref,
                          )
                        : null,
                  ),
                  StreamBuilder<PlaybackState>(
                    stream: flowAudioHandler.playbackState,
                    initialData: flowAudioHandler.playbackState.value,
                    builder: (context, snapshot) {
                      if (snapshot.data?.processingState !=
                          AudioProcessingState.error) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          LocaleKeys.radio_play_interrupted.tr(),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.error,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _stationSubtitle(RadioStation? station) {
    if (station == null) return '';
    return [
      if (station.country.isNotEmpty) station.country,
      if (station.codec.isNotEmpty) station.codec,
      if (station.bitrate > 0) '${station.bitrate} kbps',
    ].join(' · ');
  }
}

class _FlowMixFeedbackButton extends ConsumerStatefulWidget {
  const _FlowMixFeedbackButton({required this.station, required this.hasNext});

  final RadioStation station;
  final bool hasNext;

  @override
  ConsumerState<_FlowMixFeedbackButton> createState() =>
      _FlowMixFeedbackButtonState();
}

class _FlowMixFeedbackButtonState
    extends ConsumerState<_FlowMixFeedbackButton> {
  bool _isSaving = false;

  Future<void> _submit() async {
    if (_isSaving || !widget.hasNext) return;
    setState(() => _isSaving = true);
    await ref
        .read(flowMixControllerProvider.notifier)
        .lessLikeThis(widget.station);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(LocaleKeys.flow_mix_less_confirmation.tr()),
        duration: const Duration(seconds: 2),
      ),
    );
    await playNextRadioStation(context: context, ref: ref);
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      key: const Key('flow-mix-less-like-this'),
      onPressed: _isSaving || !widget.hasNext ? null : _submit,
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      icon: _isSaving
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.thumb_down_alt_outlined),
      label: Text(LocaleKeys.flow_mix_less_like_this.tr()),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.artUri, required this.colors});

  final String artUri;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.25),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: artUri.isEmpty
              ? _Placeholder(colors: colors)
              : OptimizedNetworkImage(
                  url: artUri,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _Placeholder(colors: colors),
                ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.secondary],
        ),
      ),
      child: Center(
        child: Icon(Icons.radio_rounded, size: 80, color: colors.onPrimary),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colors.primary.withValues(alpha: 0.15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            LocaleKeys.live.tr(),
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.hasNext,
    required this.hasPrevious,
    required this.onNext,
    required this.onPrevious,
  });

  final bool hasNext;
  final bool hasPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          iconSize: 40,
          onPressed: onPrevious,
          icon: Icon(
            Icons.skip_previous_rounded,
            color: hasPrevious
                ? colors.onSurface
                : colors.onSurface.withValues(alpha: 0.3),
          ),
        ),
        StreamBuilder<PlaybackState>(
          stream: flowAudioHandler.playbackState,
          initialData: flowAudioHandler.playbackState.value,
          builder: (context, snapshot) {
            final state = snapshot.data;
            final processing = state?.processingState;
            final isBuffering =
                processing == AudioProcessingState.loading ||
                processing == AudioProcessingState.buffering;
            final isPlaying = !isBuffering && (state?.playing ?? false);
            return GestureDetector(
              onTap: isBuffering
                  ? null
                  : () {
                      if (isPlaying) {
                        flowAudioHandler.pause();
                      } else {
                        flowAudioHandler.play();
                      }
                    },
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [colors.primary, colors.secondary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.45),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: isBuffering
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: colors.onPrimary,
                        ),
                      )
                    : Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: colors.onPrimary,
                        size: 40,
                      ),
              ),
            );
          },
        ),
        IconButton(
          iconSize: 40,
          onPressed: onNext,
          icon: Icon(
            Icons.skip_next_rounded,
            color: hasNext
                ? colors.onSurface
                : colors.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }
}

class _FavoriteStationButton extends ConsumerWidget {
  const _FavoriteStationButton({required this.station});

  final RadioStation station;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final favorites = ref.watch(radioFavoritesControllerProvider);
    final isFavorite = favorites.any((s) => _idOf(s) == _idOf(station));

    return IconButton(
      tooltip: isFavorite
          ? LocaleKeys.remove_from_favorites.tr()
          : LocaleKeys.add_to_favorites.tr(),
      icon: Icon(
        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: colors.primary,
      ),
      onPressed: () async {
        final added = await ref
            .read(radioFavoritesControllerProvider.notifier)
            .toggle(station);
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
      },
    );
  }

  String _idOf(RadioStation station) =>
      station.stationUuid.isEmpty ? station.streamUrl : station.stationUuid;
}
