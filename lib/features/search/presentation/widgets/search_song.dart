import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/search/data/search_history_repository.dart';
import 'package:flow_music/features/search/presentation/controllers/search_history_controller.dart';
import 'package:flow_music/features/search/presentation/pages/list_search.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ViewSearchDelegate extends SearchDelegate<void> {
  ViewSearchDelegate()
    : super(
        searchFieldLabel: LocaleKeys.search_music_label.tr(),
        searchFieldStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      );

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        toolbarHeight: 70,
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 24),
        titleTextStyle: theme.textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: theme.textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w400,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      scaffoldBackgroundColor: colorScheme.surface,
    );
  }

  @override
  void showResults(BuildContext context) {
    final normalized = normalizeSearchQuery(query);
    if (normalized.isEmpty) {
      showSuggestions(context);
      return;
    }
    query = normalized;
    unawaited(
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(searchHistoryControllerProvider.notifier).record(normalized),
    );
    super.showResults(context);
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.clear_rounded),
          tooltip: LocaleKeys.clear.tr(),
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () {
        close(context, null);
      },
      icon: const Icon(Icons.arrow_back_rounded),
      tooltip: LocaleKeys.back.tr(),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return query.isNotEmpty
        ? SuggestedListSearch(
            searchQuery: query,
            onSelect: (_) => close(context, null),
          )
        : Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                LocaleKeys.type_to_search.tr(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (normalizeSearchQuery(query).isEmpty) {
      return _RecentSearches(
        onSelected: (recentQuery) {
          query = recentQuery;
          showResults(context);
        },
      );
    }

    return SuggestedListSearch(
      searchQuery: query,
      onSelect: (_) {
        final normalized = normalizeSearchQuery(query);
        if (normalized.isNotEmpty) {
          unawaited(
            ProviderScope.containerOf(
              context,
              listen: false,
            ).read(searchHistoryControllerProvider.notifier).record(normalized),
          );
        }
        close(context, null);
      },
    );
  }
}

class _RecentSearches extends ConsumerWidget {
  const _RecentSearches({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchHistoryControllerProvider);
    final controller = ref.read(searchHistoryControllerProvider.notifier);
    final theme = Theme.of(context);

    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            LocaleKeys.no_recent_searches.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 4, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  LocaleKeys.recent_searches.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: controller.clear,
                child: Text(LocaleKeys.clear_search_history.tr()),
              ),
            ],
          ),
        ),
        ...history.map(
          (recentQuery) => ListTile(
            leading: const Icon(Icons.history_rounded),
            title: Text(
              recentQuery,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => onSelected(recentQuery),
            trailing: IconButton(
              tooltip: LocaleKeys.remove_search_history_item.tr(),
              onPressed: () => controller.remove(recentQuery),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ),
      ],
    );
  }
}
