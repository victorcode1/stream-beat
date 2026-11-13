import 'package:flow_music/core/audio/now_playing_provider.dart';
import 'package:flow_music/core/theme/desktop_theme.dart';
import 'package:flow_music/core/utils/adaptive_layout.dart';
import 'package:flow_music/features/radio/presentation/widgets/radio_search_delegate.dart';
import 'package:flow_music/features/home/presentation/controllers/home_page_controller.dart';
import 'package:flow_music/features/home/presentation/controllers/home_view_controller.dart';
import 'package:flow_music/features/home/presentation/widgets/home_desktop_sidebar.dart';
import 'package:flow_music/features/home/presentation/widgets/home_desktop_top_bar.dart';
import 'package:flow_music/features/home/presentation/widgets/home_mobile_app_bar.dart';
import 'package:flow_music/features/home/presentation/widgets/home_mobile_bottom_bar.dart';
import 'package:flow_music/features/home/presentation/widgets/home_page_content.dart';
import 'package:flow_music/features/search/presentation/widgets/search_song.dart';
import 'package:flow_music/features/song/presentation/widgets/mini_player.dart';
import 'package:flow_music/features/song/presentation/widgets/modern_player_hero.dart';
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
  final _pageController = const HomePageController();
  String? _lastRoutePath;
  @override
  Widget build(BuildContext context) {
    final viewState = ref.watch(homeViewProvider);
    final viewCtr = ref.read(homeViewProvider.notifier);
    final currentPath = GoRouterState.of(context).uri.path;
    // Radio y mapa comparten el shell, pero su busqueda es de emisoras.
    final isRadioSection =
        currentPath == '/radio' || currentPath == '/radio-map';
    final previousPath = _lastRoutePath;
    _lastRoutePath = currentPath;
    _pageController.clearSearchOnRouteChange(
      ref: ref,
      mounted: mounted,
      previousPath: previousPath,
      currentPath: currentPath,
      viewController: viewCtr,
    );

    // El mini player solo aparece cuando hay audio sonando y no estamos
    // ya viendo el reproductor completo. Cubrimos los dos modos de
    // navegacion al reproductor: por homeViewProvider (state == PlaySong)
    // o por GoRouter (ruta `/playSong`).
    //
    // Importante: `homeViewProvider` es keepAlive y conserva `PlaySong`
    // aunque el usuario salte a otra seccion por el drawer (p.ej.
    // /radio-map). En esos casos `widget.child` ya no es el SongWidget,
    // asi que el AnimatedSwitcher ignora el viewState — el chequeo de
    // viewState solo aplica cuando HomePage esta renderizando su propio
    // switch (widget.child == null).
    final nowPlayingTitle = ref.watch(nowPlayingTitleProvider).asData?.value;
    final showMiniPlayer = _pageController.shouldShowMiniPlayer(
      nowPlayingTitle: nowPlayingTitle,
      child: widget.child,
      viewState: viewState,
      currentPath: currentPath,
    );
    final showNowPlayingDetails = _pageController.shouldShowNowPlayingDetails(
      child: widget.child,
      viewState: viewState,
      currentPath: currentPath,
    );

    if (useFlowDesktopShell(context)) {
      // Estructura del mockup StreamBeat: barra superior a todo lo ancho, y
      // debajo la fila [sidebar | contenido]. El contenido pinta una
      // superficie opaca para que el fondo ambiente (con tinte de acento) no
      // se filtre en la zona central — el escritorio queda plano y oscuro como
      // el diseno.
      //
      // `FlowDesktopTheme` re-tinta las superficies al negro azulado del
      // rediseno. Se aplica aqui, envolviendo solo esta rama, para que el shell
      // movil siga con los grises neutros del tema compartido.
      return Theme(
        data: FlowDesktopTheme.of(Theme.of(context)),
        child: Builder(
          builder: (context) {
            final colors = Theme.of(context).colorScheme;
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: Column(
                children: [
                  HomeDesktopTopBar(
                    query: viewCtr.setQuery,
                    isRadioSection: isRadioSection,
                    showSearch: () async {
                      await showSearch(
                        context: context,
                        delegate: isRadioSection
                            ? RadioSearchDelegate()
                            : ViewSearchDelegate(),
                      );
                    },
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        const HomeDesktopSidebar(),
                        Expanded(
                          child: ColoredBox(
                            color: colors.surface,
                            child: HomePageContent(
                              viewState: viewState,
                              viewController: viewCtr,
                              child: widget.child,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showMiniPlayer) const MiniPlayer(desktop: true),
                ],
              ),
            );
          },
        ),
      );
    }

    final shell = Scaffold(
      backgroundColor: Colors.transparent,
      // Con el reproductor abierto la caratula sube por detras de la barra
      // superior (transparente) hasta el borde de la pantalla.
      extendBodyBehindAppBar: showNowPlayingDetails,
      // Configuracion ya trae su propia cabecera movil. La mantenemos dentro
      // de este shell para que la barra inferior no desaparezca al cambiar de
      // seccion, pero evitamos dibujar dos app bars.
      appBar: currentPath == '/settings'
          ? null
          : HomeMobileAppBar(
              query: viewCtr.setQuery,
              showNowPlayingDetails: showNowPlayingDetails,
              showMiniPlayer: showMiniPlayer,
              isRadioSection: isRadioSection,
              // Lista de categoria / busqueda abierta dentro del propio shell:
              // la flecha la cierra y devuelve las sugerencias.
              showBack:
                  widget.child == null &&
                  !showNowPlayingDetails &&
                  viewState is! Suggested,
              onBack: viewCtr.back,
            ),
      body: HomePageContent(
        viewState: viewState,
        viewController: viewCtr,
        child: widget.child,
      ),
      bottomNavigationBar: HomeMobileBottomBar(
        currentPath: currentPath,
        showNowPlayingDetails: showNowPlayingDetails,
        showMiniPlayer: showMiniPlayer,
        setQuery: viewCtr.setQuery,
      ),
    );

    if (!showNowPlayingDetails) return shell;
    // Con el reproductor abierto toda la pantalla pasa a oscuro (barra
    // superior, inferior y hora del sistema), sea cual sea el estilo.
    return ColoredBox(
      color: const Color(0xFF0B0B0C),
      child: Theme(data: playerOnDarkTheme(Theme.of(context)), child: shell),
    );
  }
}
