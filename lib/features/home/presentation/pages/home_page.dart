import 'package:flow_music/core/theme/player_dark_theme.dart';
import 'package:flow_music/core/audio/radio_mini_player.dart';
import 'package:flow_music/core/utils/adaptive_layout.dart';
import 'package:flow_music/features/home/presentation/providers/text_search.dart';
import 'package:flow_music/features/home/presentation/widgets/home_desktop_sidebar.dart';
import 'package:flow_music/features/home/presentation/widgets/home_desktop_top_bar.dart';
import 'package:flow_music/features/home/presentation/widgets/home_mobile_app_bar.dart';
import 'package:flow_music/features/home/presentation/widgets/home_mobile_bottom_bar.dart';
import 'package:flow_music/features/home/presentation/widgets/home_page_content.dart';
import 'package:flow_music/features/monetization/presentation/widgets/exit_confirmation_scope.dart';
import 'package:flow_music/features/radio/presentation/widgets/radio_station_search_view.dart';
import 'package:flutter/material.dart' hide SearchDelegate;
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class HomePage extends ConsumerStatefulWidget {
  final Widget? child;

  const HomePage({super.key, this.child});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _isSearching = false;

  void _openSearch() {
    setState(() => _isSearching = true);
  }

  void _closeSearch() {
    ref.read(searchProvider).clear();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSearching = false);
  }

  void _handleDesktopSearch(String value) {
    final shouldShowSearch = value.trim().isNotEmpty;
    if (_isSearching == shouldShowSearch) return;
    setState(() => _isSearching = shouldShowSearch);
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    final searchController = ref.read(searchProvider);
    final pageContent = _isSearching
        ? const RadioStationSearchView()
        : widget.child;

    if (supportsFlowDesktopShell && useFlowWideLayout(context)) {
      final colors = Theme.of(context).colorScheme;
      // Estructura del mockup StreamBeat: barra superior a todo lo ancho, y
      // debajo la fila [sidebar | contenido]. El contenido pinta una
      // superficie opaca para que el fondo ambiente (con tinte de acento) no
      // se filtre en la zona central — el escritorio queda plano y oscuro como
      // el diseno.
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            HomeDesktopTopBar(query: _handleDesktopSearch),
            Expanded(
              child: Row(
                children: [
                  const HomeDesktopSidebar(),
                  Expanded(
                    child: ColoredBox(
                      color: colors.surface,
                      child: HomePageContent(child: pageContent),
                    ),
                  ),
                ],
              ),
            ),
            if (currentPath != '/radio-player') const RadioMiniPlayer(),
          ],
        ),
      );
    }

    // Back closes an open search first; only then may it leave the app.
    return PopScope(
      canPop: !_isSearching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSearching) _closeSearch();
      },
      child: ExitConfirmationScope(
        enabled: !_isSearching,
        child: _mobileScaffold(currentPath, searchController, pageContent),
      ),
    );
  }

  Widget _mobileScaffold(
    String currentPath,
    TextEditingController searchController,
    Widget? pageContent,
  ) {
    final shell = Scaffold(
      backgroundColor: Colors.transparent,
      // Configuracion y el reproductor traen su propia cabecera. Ambos viven
      // dentro de este shell para conservar la navegacion inferior.
      appBar: currentPath == '/settings' || currentPath == '/radio-player'
          ? null
          : HomeMobileAppBar(
              onSearch: _openSearch,
              isSearching: _isSearching,
              searchController: searchController,
              onCloseSearch: _closeSearch,
            ),
      body: HomePageContent(child: pageContent),
      bottomNavigationBar: HomeMobileBottomBar(currentPath: currentPath),
    );

    if (currentPath != '/radio-player') return shell;
    // Con el reproductor abierto toda la pantalla pasa a oscuro (portada,
    // barra inferior y hora del sistema), sea cual sea el estilo.
    return ColoredBox(
      color: const Color(0xFF0B0B0C),
      child: Theme(data: playerOnDarkTheme(Theme.of(context)), child: shell),
    );
  }
}
