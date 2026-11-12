import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:audio_service/audio_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/audio/audio_playing_provider.dart';
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
import 'package:flow_music/shared/widgets/playing_bars_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    return Scaffold(
      // La pagina pinta su propio fondo: la portada ocupa la parte de arriba
      // (tambien detras de la barra de estado) y se funde con la superficie.
      backgroundColor: colors.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        leadingWidth: 64,
        leading: Center(
          child: _GlassPill(
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        actions: [
          if (station != null)
            _GlassPill(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(
                    builder: (shareContext) => IconButton(
                      tooltip: LocaleKeys.share_station.tr(),
                      icon: const Icon(Icons.share_rounded),
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
                    icon: const Icon(Icons.playlist_add_rounded),
                    onPressed: () => showAddToRadioPlaylistFlow(
                      context: context,
                      ref: ref,
                      station: station,
                    ),
                  ),
                  _FavoriteStationButton(station: station),
                  StationActionsMenu(station: station),
                ],
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: StreamBuilder<MediaItem?>(
        stream: flowAudioHandler.mediaItem,
        builder: (context, snapshot) {
          final item = snapshot.data;
          final title = item?.title ?? station?.name ?? '';
          final subtitle = item?.artist ?? _stationSubtitle(station);
          final artUri = item?.artUri?.toString() ?? station?.artworkUrl ?? '';

          return LayoutBuilder(
            builder: (context, constraints) {
              final heroHeight = math.min(
                constraints.maxWidth * 1.1,
                constraints.maxHeight * 0.62,
              );
              return Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: heroHeight,
                    child: _HeroArtwork(artUri: artUri, colors: colors),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Spacer(),
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
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
                          const SizedBox(height: 28),
                          _Controls(
                            hasNext: radioQueue.hasNext,
                            hasPrevious: radioQueue.hasPrevious,
                            onNext: radioQueue.hasNext
                                ? () => playNextRadioStation(
                                    context: context,
                                    ref: ref,
                                  )
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
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
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

/// Portada a todo lo ancho, como el banner de Shazam: arriba un velo oscuro
/// para que se lean la barra de estado y los botones, y abajo un degradado que
/// la funde con la superficie donde van el titulo y los controles.
class _HeroArtwork extends StatelessWidget {
  const _HeroArtwork({required this.artUri, required this.colors});

  final String artUri;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        artUri.isEmpty
            ? _Placeholder(colors: colors)
            : OptimizedNetworkImage(
                url: artUri,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _Placeholder(colors: colors),
              ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.22, 0.5, 0.82, 1],
              colors: [
                Colors.black.withValues(alpha: 0.45),
                Colors.black.withValues(alpha: 0),
                colors.surface.withValues(alpha: 0),
                colors.surface.withValues(alpha: 0.85),
                colors.surface,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Capsula translucida para que los iconos se lean sobre cualquier portada.
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.28),
          child: child,
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
          StreamBuilder<PlaybackState>(
            stream: flowAudioHandler.playbackState,
            initialData: flowAudioHandler.playbackState.value,
            builder: (context, snapshot) {
              final state = snapshot.data;
              return PlayingBarsIndicator(
                isPlaying: state != null && isAudiblePlayback(state),
                color: colors.primary,
                size: 14,
              );
            },
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
