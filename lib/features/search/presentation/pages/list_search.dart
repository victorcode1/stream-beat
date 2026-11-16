import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/audio/now_playing_provider.dart';
import 'package:flow_music/features/autoplay/presentation/controllers/autoplay_queue_controller.dart';
import 'package:flow_music/features/home/presentation/controllers/home_view_controller.dart';
import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/core/theme/custom_theme.dart';
import 'package:flow_music/core/utils/adaptive_layout.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/search/presentation/providers/list_quick_search_data.dart';
import 'package:flow_music/features/search/presentation/widgets/search_results_desktop.dart';
import 'package:flow_music/features/settings/presentation/controllers/autoplay_enabled_controller.dart';
import 'package:flow_music/features/song/presentation/controllers/artist_playback_controller.dart';
import 'package:flow_music/features/song/presentation/widgets/artist_song_tile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flow_music/features/song/presentation/controllers/song_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SuggestedListSearch extends ConsumerWidget {
  /// Se invoca tras seleccionar (y empezar a reproducir) una sugerencia. Lo
  /// usa el buscador para cerrar su overlay y revelar el reproductor.
  final void Function(YouTubeSearchSuggestion)? onSelect;
  final String? searchQuery;
  final bool playInPlace;
  const SuggestedListSearch({
    super.key,
    this.searchQuery,
    this.onSelect,
    this.playInPlace = false,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSearch = ref.watch(searchDataReqProvider(search: searchQuery));
    final currentId = playInPlace
        ? ref.watch(
            songController.select((controller) => controller.currentVideoId),
          )
        : null;
    final isPlaying = playInPlace
        ? ref.watch(nowPlayingIsPlayingProvider).value ?? false
        : false;
    return asyncSearch.when(
      data: (suggestions) {
        final List<YouTubeSearchSuggestion> results = suggestions;
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final textTheme = theme.textTheme;
        final extras = theme.extension<FlowThemeExtras>();

        void onItemTap(int index) {
          final suggestion = results[index];
          if (suggestion.videoId.isEmpty) return;
          if (playInPlace) {
            final playback = ref.read(artistPlaybackControllerProvider);
            unawaited(playback.play(results, index, isPlaying: isPlaying));
            onSelect?.call(suggestion);
            return;
          }
          if (ref.read(autoplayEnabledControllerProvider)) {
            ref
                .read(autoplayQueueControllerProvider.notifier)
                .enqueue(results, index);
          } else {
            ref.read(autoplayQueueControllerProvider.notifier).clear();
          }
          ref.read(homeViewProvider.notifier).listen(suggestion);
          onSelect?.call(suggestion);
        }

        if (results.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 40,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  color: colors.surface,
                  border: Border.all(
                    color: colors.outline.withValues(alpha: 0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.08),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: colors.scrim.withValues(
                        alpha: theme.brightness == Brightness.dark ? 0.3 : 0.06,
                      ),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: extras?.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.music_note_rounded,
                        size: 40,
                        color: colors.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      LocaleKeys.no_suggestions.tr(),
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (searchQuery?.isNotEmpty ?? false)
                      Text(
                        LocaleKeys.try_complete_search.tr(args: [searchQuery!]),
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }

        // La busqueda rapida de la barra superior caia siempre en las
        // tarjetas moviles (ancho completo, radio 28 y el violeta del fondo
        // ambiente), asi que dentro del shell de escritorio el rediseno se
        // perdia en cuanto se escribia. En escritorio reusa la misma vista a
        // dos columnas que los resultados completos.
        if (!playInPlace && useFlowDesktopShell(context)) {
          return SearchResultsDesktop(items: results, onPlay: onItemTap);
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          itemCount: results.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final suggestion = results[index];
            if (playInPlace) {
              final isCurrent = suggestion.videoId == currentId;
              return ArtistSongTile(
                song: suggestion,
                isCurrent: isCurrent,
                isPlaying: isCurrent && isPlaying,
                onTap: () => onItemTap(index),
              );
            }
            final query = suggestion.query;
            final subtitle = suggestion.channelTitle.isNotEmpty
                ? suggestion.channelTitle
                : LocaleKeys.view_related_results.tr();
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => onItemTap(index),

                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: colors.surface,
                    border: Border.all(
                      color: colors.outline.withValues(alpha: 0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.scrim.withValues(
                          alpha: theme.brightness == Brightness.dark
                              ? 0.25
                              : 0.04,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      _SuggestionArtwork(
                        imageUrl: suggestion.thumbnailUrl,
                        extras: extras,
                        colors: colors,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              query,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: colors.primary.withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 20,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      error: (error, stack) => Center(
        child: Column(
          children: [
            Flexible(
              child: Text(
                kDebugMode
                    ? '${LocaleKeys.error_loading_data.tr()} $error\n$stack'
                    : LocaleKeys.error_loading_data.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () => ref
                  .read(searchDataReqProvider(search: searchQuery).notifier)
                  .reload(),
              child: Text(LocaleKeys.retry.tr()),
            ),
          ],
        ),
      ),
      loading: () => const Center(
        child: CircularProgressIndicator.adaptive(strokeWidth: 2),
      ),
    );
  }
}

class _SuggestionArtwork extends StatelessWidget {
  const _SuggestionArtwork({
    required this.imageUrl,
    required this.extras,
    required this.colors,
  });

  final String imageUrl;
  final FlowThemeExtras? extras;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      width: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) =>
                  _SuggestionArtworkFallback(extras: extras, colors: colors),
            )
          : _SuggestionArtworkFallback(extras: extras, colors: colors),
    );
  }
}

class _SuggestionArtworkFallback extends StatelessWidget {
  const _SuggestionArtworkFallback({
    required this.extras,
    required this.colors,
  });

  final FlowThemeExtras? extras;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: extras?.primaryGradient,
        color: extras?.primaryGradient == null ? colors.primary : null,
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: colors.onPrimary,
          size: 26,
        ),
      ),
    );
  }
}
