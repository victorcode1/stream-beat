import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/features/autoplay/presentation/controllers/autoplay_queue_controller.dart';
import 'package:flow_music/features/search/presentation/controllers/search_history_controller.dart';
import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/core/audio/now_playing_provider.dart';
import 'package:flow_music/core/utils/adaptive_layout.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/search/presentation/providers/list_search_result.dart';
import 'package:flow_music/features/search/presentation/widgets/search_results_desktop.dart';
import 'package:flow_music/features/settings/presentation/controllers/autoplay_enabled_controller.dart';
import 'package:flow_music/shared/widgets/song_row.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ListSongs extends ConsumerWidget {
  const ListSongs({super.key, required this.data, required this.listen});

  final String data;
  final void Function(YouTubeSearchSuggestion) listen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final asyncSongs = ref.watch(searchResultDataProvider(data));

    void onItemTap(List<YouTubeSearchSuggestion> items, int index) {
      unawaited(
        ref.read(searchHistoryControllerProvider.notifier).record(data),
      );
      if (ref.read(autoplayEnabledControllerProvider)) {
        ref
            .read(autoplayQueueControllerProvider.notifier)
            .enqueue(items, index);
      } else {
        ref.read(autoplayQueueControllerProvider.notifier).clear();
      }
      listen(items[index]);
    }

    return asyncSongs.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                LocaleKeys.no_results.tr(),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          );
        }

        // Antes esta rama estaba limitada a `kIsWeb`, asi que en macOS los
        // resultados caian en el layout movil: tarjetas de 28px de radio
        // estiradas a todo el ancho de la ventana. Ahora la condicion es el
        // shell de escritorio, que cubre macOS, Windows, Linux y web.
        if (useFlowDesktopShell(context)) {
          return SearchResultsDesktop(
            items: items,
            onPlay: (index) => onItemTap(items, index),
          );
        }

        final currentId = ref.watch(nowPlayingIdProvider).value;
        final isPlaying = ref.watch(nowPlayingIsPlayingProvider).value ?? false;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final suggestion = items[index];
            final isCurrent = suggestion.videoId == currentId;
            return SongRow(
              title: suggestion.displayText,
              subtitle: suggestion.channelTitle,
              artworkUrl: suggestion.thumbnailUrl,
              duration: suggestion.duration,
              isCurrent: isCurrent,
              isPlaying: isCurrent && isPlaying,
              onTap: () => onItemTap(items, index),
            );
          },
        );
      },
      error: (error, stack) {
        debugPrint('Error fetching search results: $error $stack');
        return Center(
          child: Text(LocaleKeys.error.tr(), textAlign: TextAlign.center),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator.adaptive(strokeWidth: 2),
      ),
    );
  }
}
