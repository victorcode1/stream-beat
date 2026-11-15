import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/home/presentation/controllers/home_page_controller.dart';
import 'package:flow_music/features/home/presentation/providers/text_search.dart';
import 'package:flow_music/features/monetization/presentation/widgets/respectful_banner_slot.dart';
import 'package:flow_music/features/song/presentation/widgets/mini_player.dart';
import 'package:flow_music/shared/widgets/flow_bottom_nav.dart';
import 'package:flutter/material.dart' hide SearchDelegate;
import 'package:flutter/widget_previews.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class HomeMobileBottomBar extends ConsumerWidget {
  const HomeMobileBottomBar({
    super.key,
    required this.currentPath,
    required this.showNowPlayingDetails,
    required this.showMiniPlayer,
    required this.setQuery,
  });

  final String currentPath;
  final bool showNowPlayingDetails;
  final bool showMiniPlayer;
  final void Function(String query) setQuery;

  static const _pageController = HomePageController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = ref.read(searchProvider);
    final navPath = _pageController.navigationPath(
      currentPath: currentPath,
      basePath: GoRouter.maybeOf(
        context,
      )?.routerDelegate.currentConfiguration.uri.path,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const RespectfulBannerSlot(),
        if (showMiniPlayer) const MiniPlayer(),
        FlowBottomNav(
          destinations: [
            FlowNavDestination(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: LocaleKeys.home.tr(),
              selected: navPath == '/home',
              onTap: () => _pageController.navigateToTab(
                // El reproductor tambien puede vivir en el estado interno de
                // `/home`. Lo tratamos como una subruta para que volver a
                // tocar Inicio cierre el reproductor y restaure sugerencias.
                currentPath: showNowPlayingDetails ? '/playSong' : currentPath,
                targetPath: '/home',
                searchController: searchController,
                setQuery: setQuery,
                navigateTo: context.go,
              ),
            ),
            FlowNavDestination(
              icon: Icons.library_music_outlined,
              activeIcon: Icons.library_music_rounded,
              label: LocaleKeys.library.tr(),
              selected: navPath == '/library',
              onTap: () => _pageController.navigateToTab(
                currentPath: currentPath,
                targetPath: '/library',
                searchController: searchController,
                setQuery: setQuery,
                navigateTo: context.go,
              ),
            ),
            FlowNavDestination(
              icon: Icons.radio,
              activeIcon: Icons.radio_rounded,
              label: LocaleKeys.radio.tr(),
              selected: navPath == '/radio',
              onTap: () => _pageController.navigateToTab(
                currentPath: currentPath,
                targetPath: '/radio',
                searchController: searchController,
                setQuery: setQuery,
                navigateTo: context.go,
              ),
            ),
            FlowNavDestination(
              icon: Icons.travel_explore_outlined,
              activeIcon: Icons.travel_explore_rounded,
              label: LocaleKeys.radio_map_explorer_short.tr(),
              selected: navPath == '/radio-map',
              onTap: () => _pageController.navigateToTab(
                currentPath: currentPath,
                targetPath: '/radio-map',
                searchController: searchController,
                setQuery: setQuery,
                navigateTo: context.go,
              ),
            ),
            FlowNavDestination(
              icon: Icons.favorite_border_rounded,
              activeIcon: Icons.favorite_rounded,
              label: LocaleKeys.favorites.tr(),
              selected: navPath == '/favorites',
              onTap: () => _pageController.navigateToTab(
                currentPath: currentPath,
                targetPath: '/favorites',
                searchController: searchController,
                setQuery: setQuery,
                navigateTo: context.go,
              ),
            ),
            FlowNavDestination(
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings_rounded,
              label: LocaleKeys.settings_short.tr(),
              selected: navPath == '/settings',
              onTap: () => _pageController.navigateToTab(
                currentPath: currentPath,
                targetPath: '/settings',
                searchController: searchController,
                setQuery: setQuery,
                navigateTo: context.go,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

@Preview(name: 'Home mobile bottom nav')
Widget previewHomeMobileBottomNav() {
  return MaterialApp(
    home: Scaffold(
      bottomNavigationBar: HomeMobileBottomBar(
        currentPath: '/home',
        showNowPlayingDetails: false,
        showMiniPlayer: false,
        setQuery: (_) {},
      ),
    ),
  );
}
