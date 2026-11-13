import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/core/utils/adaptive_layout.dart';
import 'package:flow_music/features/autoplay/presentation/controllers/autoplay_queue_controller.dart';
import 'package:flow_music/features/history/data/playback_history_entry.dart';
import 'package:flow_music/features/history/presentation/controllers/playback_history_controller.dart';
import 'package:flow_music/features/home/presentation/controllers/home_view_controller.dart';
import 'package:flow_music/features/home/presentation/providers/home_suggestions_provider.dart';
import 'package:flow_music/features/home/presentation/widgets/home_mobile_sections.dart';
import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/features/settings/presentation/controllers/autoplay_enabled_controller.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Categorias rapidas del home (chips "Descubre"), igual al diseno StreamBeat.
enum _HomeCategoryKind { forYou, radio, genre }

/// Un chip del carrusel de categorias del home.
///
/// Los dos que no son genero se comportan distinto: "Para ti" pide otra tanda de
/// sugerencias y "Radio" cambia de seccion. El resto son generos que se buscan
/// en YouTube.
class _HomeCategory {
  const _HomeCategory.forYou(this.label) : kind = _HomeCategoryKind.forYou;
  const _HomeCategory.radio(this.label) : kind = _HomeCategoryKind.radio;
  const _HomeCategory.genre(this.label) : kind = _HomeCategoryKind.genre;

  final _HomeCategoryKind kind;
  final String label;

  /// Busqueda de un chip de genero. El "mix" empuja a YouTube hacia
  /// recopilatorios del genero en vez de una cancion suelta, y sale en el idioma
  /// de la etiqueta sin tener que traducir la query aparte.
  String get searchQuery => '$label mix';
}

/// Nombres de genero que son iguales en cualquier idioma van tal cual; los que
/// cambian salen de las traducciones.
List<_HomeCategory> _homeCategories() => <_HomeCategory>[
  _HomeCategory.forYou(LocaleKeys.category_for_you.tr()),
  _HomeCategory.genre(LocaleKeys.category_pop.tr()),
  _HomeCategory.genre(LocaleKeys.category_reggaeton.tr()),
  const _HomeCategory.genre('Salsa'),
  const _HomeCategory.genre('Bachata'),
  const _HomeCategory.genre('Merengue'),
  const _HomeCategory.genre('Cumbia'),
  const _HomeCategory.genre('Vallenato'),
  const _HomeCategory.genre('Rock'),
  const _HomeCategory.genre('Trap'),
  const _HomeCategory.genre('Hip hop'),
  _HomeCategory.genre(LocaleKeys.category_electronic.tr()),
  _HomeCategory.genre(LocaleKeys.category_ballads.tr()),
  const _HomeCategory.genre('Jazz'),
  const _HomeCategory.genre('K-pop'),
  _HomeCategory.genre(LocaleKeys.category_classical.tr()),
  _HomeCategory.radio(LocaleKeys.radio.tr()),
];

/// Sugerencias iniciales en la pantalla `home` cuando no hay busqueda ni
/// reproduccion en curso.
///
/// Si el usuario tiene permiso de ubicacion y el GPS activo, muestra musica
/// popular de su pais. Sino, queries aleatorias para evitar pantalla vacia.
class HomeSuggestions extends ConsumerWidget {
  const HomeSuggestions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final asyncSuggestions = ref.watch(homeSuggestionsProvider);
    final history = ref
        .watch(playbackHistoryControllerProvider)
        .take(10)
        .toList();
    final viewCtr = ref.read(homeViewProvider.notifier);

    return asyncSuggestions.when(
      data: (result) {
        if (result.suggestions.isEmpty) {
          return _EmptyState(
            onRetry: () => ref.read(homeSuggestionsProvider.notifier).refresh(),
          );
        }

        // Al tocar una sugerencia del home encolamos toda la lista centrada en
        // la cancion tocada. Esto arranca el prefetch rodante en segundo plano
        // de las siguientes pistas (ver AutoplayQueueController._pumpPrefetch)
        // para que el boton "next" pueda avanzar al instante.
        void playFrom(
          List<YouTubeSearchSuggestion> items,
          YouTubeSearchSuggestion suggestion,
        ) {
          final index = items.indexWhere(
            (s) => s.videoId == suggestion.videoId,
          );
          final notifier = ref.read(autoplayQueueControllerProvider.notifier);
          if (ref.read(autoplayEnabledControllerProvider) && index >= 0) {
            notifier.enqueue(items, index);
          } else {
            notifier.clear();
          }
          viewCtr.listen(suggestion);
        }

        void onSuggestionTap(YouTubeSearchSuggestion suggestion) =>
            playFrom(result.suggestions, suggestion);

        // Una cache guardada antes de separar las secciones solo trae la
        // lista mezclada: se muestra entera como «Para ti».
        final forYou = result.forYou.isNotEmpty
            ? result.forYou
            : result.chart.isEmpty
            ? result.suggestions
            : const <YouTubeSearchSuggestion>[];

        void onCategory(_HomeCategory category) {
          switch (category.kind) {
            case _HomeCategoryKind.forYou:
              ref.read(homeSuggestionsProvider.notifier).refresh();
            case _HomeCategoryKind.radio:
              context.go('/radio');
            case _HomeCategoryKind.genre:
              viewCtr.showListSearch(category.searchQuery);
          }
        }

        return _SuggestionsGrid(
          items: result.suggestions,
          chart: result.chart,
          forYou: forYou,
          countryName: result.countryName,
          onChartTap: (item) => playFrom(result.chart, item),
          onForYouTap: (item) => playFrom(forYou, item),
          history: history,
          userName: null,
          onCategory: onCategory,
          onTap: onSuggestionTap,
          onHistoryTap: (entry) {
            if (entry.kind == PlaybackHistoryKind.radio) {
              context.go('/radio');
              return;
            }
            final suggestions = history
                .where((e) => e.kind != PlaybackHistoryKind.radio)
                .map(
                  (e) => YouTubeSearchSuggestion(
                    videoId: e.id,
                    displayText: e.title,
                    channelTitle: e.subtitle,
                    thumbnailUrl: e.thumbnailUrl,
                  ),
                )
                .toList(growable: false);
            final selectedIndex = suggestions.indexWhere(
              (s) => s.videoId == entry.id,
            );
            if (selectedIndex < 0) return;
            ref
                .read(autoplayQueueControllerProvider.notifier)
                .enqueue(suggestions, selectedIndex);
            viewCtr.listen(suggestions[selectedIndex]);
          },
          onRefresh: () => ref.read(homeSuggestionsProvider.notifier).refresh(),
        );
      },
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                LocaleKeys.error.tr(),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () =>
                    ref.read(homeSuggestionsProvider.notifier).refresh(),
                child: Text(LocaleKeys.retry.tr()),
              ),
            ],
          ),
        ),
      ),
      loading: () => const Center(
        child: CircularProgressIndicator.adaptive(strokeWidth: 2),
      ),
    );
  }
}

/// Fila de chips de categoria del home. "Para ti" queda activo (verde solido);
/// el resto dispara una busqueda por genero o navega a radio.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.onCategory});

  final void Function(_HomeCategory) onCategory;

  @override
  Widget build(BuildContext context) {
    final categories = _homeCategories();

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = categories[index];
          return _CategoryChip(
            label: category.label,
            selected: category.kind == _HomeCategoryKind.forYou,
            onTap: () => onCategory(category),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: selected ? colors.primary : colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected ? colors.onPrimary : colors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionsGrid extends StatelessWidget {
  const _SuggestionsGrid({
    required this.items,
    required this.chart,
    required this.forYou,
    required this.countryName,
    required this.onChartTap,
    required this.onForYouTap,
    required this.history,
    required this.userName,
    required this.onCategory,
    required this.onTap,
    required this.onHistoryTap,
    required this.onRefresh,
  });

  final List<YouTubeSearchSuggestion> items;
  final List<YouTubeSearchSuggestion> chart;
  final List<YouTubeSearchSuggestion> forYou;
  final String? countryName;
  final ValueChanged<YouTubeSearchSuggestion> onChartTap;
  final ValueChanged<YouTubeSearchSuggestion> onForYouTap;
  final List<PlaybackHistoryEntry> history;
  final String? userName;
  final void Function(_HomeCategory) onCategory;
  final void Function(YouTubeSearchSuggestion) onTap;
  final void Function(PlaybackHistoryEntry) onHistoryTap;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    if (useFlowDesktopShell(context)) {
      return _WebSuggestionsGrid(
        items: items,
        history: history,
        userName: userName,
        onCategory: onCategory,
        onTap: onTap,
        onHistoryTap: onHistoryTap,
        onRefresh: onRefresh,
      );
    }

    // Inicio movil: primero lo que sonaba, para retomarlo con un toque; luego
    // lo escuchado hace poco, los exitos del pais numerados, «Para ti» y los
    // generos para explorar.
    final continueEntry = history.isEmpty ? null : history.first;
    final recent = history.skip(1).toList(growable: false);
    final chartTitle = countryName == null || countryName!.isEmpty
        ? LocaleKeys.chart_now.tr()
        : LocaleKeys.chart_in_country.tr(args: [countryName!]);
    var sectionIndex = 0;

    SliverToBoxAdapter header(String title, {Widget? trailing}) {
      final index = sectionIndex++;
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
          child: HomeSectionHeader(
            title: title,
            index: index,
            trailing: trailing,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (continueEntry != null) ...[
            header(LocaleKeys.continue_listening.tr()),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: ContinueListeningCard(
                  entry: continueEntry,
                  onTap: () => onHistoryTap(continueEntry),
                ),
              ),
            ),
          ],
          if (recent.isNotEmpty) ...[
            header(
              LocaleKeys.recently_played.tr(),
              trailing: TextButton(
                onPressed: () => context.go('/library'),
                child: Text(LocaleKeys.see_all.tr()),
              ),
            ),
            SliverToBoxAdapter(
              child: HomeCoverRow<PlaybackHistoryEntry>(
                items: recent,
                size: 112,
                title: (entry) => entry.title,
                subtitle: (entry) => entry.subtitle,
                artwork: (entry) => entry.thumbnailUrl,
                onTap: onHistoryTap,
              ),
            ),
          ],
          if (chart.isNotEmpty) ...[
            header(chartTitle),
            SliverToBoxAdapter(
              child: HomeChartList(items: chart, onTap: onChartTap),
            ),
          ],
          if (forYou.isNotEmpty) ...[
            header(
              LocaleKeys.category_for_you.tr(),
              trailing: IconButton(
                tooltip: LocaleKeys.retry.tr(),
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            SliverToBoxAdapter(
              child: HomeCoverRow<YouTubeSearchSuggestion>(
                items: forYou,
                size: 148,
                title: (item) => item.displayText,
                subtitle: (item) => item.channelTitle,
                artwork: (item) => item.thumbnailUrl,
                onTap: onForYouTap,
              ),
            ),
          ],
          header(LocaleKeys.explore_genres.tr()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 0, 120),
            sliver: SliverToBoxAdapter(
              child: _CategoryChips(onCategory: onCategory),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inicio en escritorio (diseno StreamBeat): saludo grande, hero destacado y
/// rejillas de caratulas a todo el ancho. Pinta sobre la superficie opaca del
/// shell para que el escritorio quede plano y oscuro, sin el lavado de acento.
class _WebSuggestionsGrid extends StatelessWidget {
  const _WebSuggestionsGrid({
    required this.items,
    required this.history,
    required this.userName,
    required this.onCategory,
    required this.onTap,
    required this.onHistoryTap,
    required this.onRefresh,
  });

  final List<YouTubeSearchSuggestion> items;
  final List<PlaybackHistoryEntry> history;
  final String? userName;
  final void Function(_HomeCategory) onCategory;
  final void Function(YouTubeSearchSuggestion) onTap;
  final void Function(PlaybackHistoryEntry) onHistoryTap;
  final VoidCallback onRefresh;

  static const _gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 230,
    mainAxisSpacing: 20,
    crossAxisSpacing: 20,
    childAspectRatio: 0.80,
  );

  @override
  Widget build(BuildContext context) {
    final featured = items.first;
    final madeForYou = items.skip(1).take(10).toList(growable: false);

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: flowContentMaxWidth),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Saludo grande + refrescar
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(40, 30, 40, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(child: _WebGreeting(userName: userName)),
                      TextButton.icon(
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        label: Text(LocaleKeys.retry.tr()),
                      ),
                    ],
                  ),
                ),
              ),
              // Chips de categoria (filtros funcionales)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(40, 18, 40, 0),
                sliver: SliverToBoxAdapter(
                  child: _CategoryChips(onCategory: onCategory),
                ),
              ),
              // Hero destacado a todo el ancho
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(40, 26, 40, 0),
                sliver: SliverToBoxAdapter(
                  child: _WebHero(
                    suggestion: featured,
                    onTap: () => onTap(featured),
                  ),
                ),
              ),
              // Hecho para ti
              if (madeForYou.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(40, 34, 40, 16),
                  sliver: SliverToBoxAdapter(
                    child: _WebSectionHeader(
                      title: LocaleKeys.made_for_you.tr(),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 8),
                  sliver: SliverGrid(
                    gridDelegate: _gridDelegate,
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final s = madeForYou[index];
                      return _WebArtCard(
                        imageUrl: s.thumbnailUrl,
                        title: s.displayText,
                        subtitle: s.channelTitle.isEmpty
                            ? null
                            : s.channelTitle,
                        onTap: () => onTap(s),
                      );
                    }, childCount: madeForYou.length),
                  ),
                ),
              ],
              // Escuchado recientemente
              if (history.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(40, 24, 40, 16),
                  sliver: SliverToBoxAdapter(
                    child: _WebSectionHeader(
                      title: LocaleKeys.recently_played.tr(),
                      onSeeAll: () => context.go('/library'),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 48),
                  sliver: SliverGrid(
                    gridDelegate: _gridDelegate,
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final entry = history[index];
                      return _WebArtCard(
                        imageUrl: entry.thumbnailUrl,
                        title: entry.title,
                        subtitle: entry.subtitle.isEmpty
                            ? null
                            : entry.subtitle,
                        fallbackIcon: entry.kind == PlaybackHistoryKind.radio
                            ? Icons.radio_rounded
                            : Icons.music_note_rounded,
                        onTap: () => onHistoryTap(entry),
                      );
                    }, childCount: history.length),
                  ),
                ),
              ] else
                const SliverToBoxAdapter(child: SizedBox(height: 48)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Saludo "Buenas tardes, {nombre}" del inicio en escritorio.
class _WebGreeting extends StatelessWidget {
  const _WebGreeting({required this.userName});

  final String? userName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    final greetingKey = hour < 12
        ? LocaleKeys.greeting_morning
        : hour < 19
        ? LocaleKeys.greeting_afternoon
        : LocaleKeys.greeting_evening;
    final name = userName?.trim();
    final text = (name != null && name.isNotEmpty)
        ? '${greetingKey.tr()}, $name'
        : greetingKey.tr();

    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
    );
  }
}

/// Encabezado de seccion ("Hecho para ti", "Escuchado recientemente") con un
/// "Ver todo" opcional a la derecha.
class _WebSectionHeader extends StatelessWidget {
  const _WebSectionHeader({required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: colors.onSurfaceVariant,
            ),
            child: Text(LocaleKeys.see_all.tr()),
          ),
      ],
    );
  }
}

/// Banner destacado a todo el ancho del inicio en escritorio. Usa la caratula
/// del primer resultado con un degradado para legibilidad y un boton blanco
/// "Reproducir" (toda la tarjeta reproduce al tocar).
class _WebHero extends StatelessWidget {
  const _WebHero({required this.suggestion, required this.onTap});

  final YouTubeSearchSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final image = suggestion.thumbnailUrl;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        // El Stack se dimensiona segun el contenido (el hijo no posicionado),
        // con una altura minima de banner. Asi el hero crece si el titulo
        // ocupa dos lineas y nunca desborda.
        child: Stack(
          children: [
            Positioned.fill(
              child: image.isNotEmpty
                  ? Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _GradientPlaceholder(colors: colors),
                    )
                  : _GradientPlaceholder(colors: colors),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      colors.scrim.withValues(alpha: 0.10),
                      colors.scrim.withValues(alpha: 0.82),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      colors.scrim.withValues(alpha: 0.55),
                    ],
                    stops: const [0.45, 1],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 196),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocaleKeys.featured.tr().toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      suggestion.displayText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (suggestion.channelTitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        suggestion.channelTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.play_arrow_rounded,
                            color: Color(0xFF101014),
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            LocaleKeys.play.tr(),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: const Color(0xFF101014),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de caratula cuadrada con titulo y subtitulo, para las rejillas del
/// inicio en escritorio ("Hecho para ti" y "Escuchado recientemente").
class _WebArtCard extends StatelessWidget {
  const _WebArtCard({
    required this.imageUrl,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.fallbackIcon,
  });

  final String imageUrl;
  final String title;
  final String? subtitle;
  final IconData? fallbackIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    Widget placeholder() => fallbackIcon != null
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Icon(fallbackIcon, color: colors.primary, size: 30),
            ),
          )
        : _GradientPlaceholder(colors: colors);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: imageUrl.isEmpty
                  ? placeholder()
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, _, _) => placeholder(),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _GradientPlaceholder extends StatelessWidget {
  const _GradientPlaceholder({required this.colors});

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
        child: Icon(
          Icons.library_music_rounded,
          color: colors.onPrimary,
          size: 32,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_music_rounded,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              LocaleKeys.no_suggestions.tr(),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: Text(LocaleKeys.retry.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
