import 'package:flow_music/features/home/presentation/controllers/home_view_controller.dart';
import 'package:flow_music/features/home/presentation/providers/text_search.dart';
import 'package:flow_music/features/song/presentation/pages/song.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Coordina decisiones de pagina para HomePage que no pertenecen al layout.
class HomePageController {
  const HomePageController();

  void navigateToTab({
    required String currentPath,
    required String targetPath,
    required TextEditingController searchController,
    required void Function(String query) setQuery,
    required void Function(String path) navigateTo,
  }) {
    // Volver a tocar la pestana activa no navega, pero si limpia lo que haya
    // encima. Antes salia de una: con una busqueda de categoria abierta dentro
    // de /home (Pop, Reggaeton...) tocar Inicio no hacia nada y el usuario se
    // quedaba sin forma de volver a las sugerencias.
    if (searchController.text.isNotEmpty) {
      searchController.clear();
    }
    setQuery('');
    FocusManager.instance.primaryFocus?.unfocus();

    if (currentPath == targetPath) return;
    navigateTo(targetPath);
  }

  void clearSearchOnRouteChange({
    required WidgetRef ref,
    required bool mounted,
    required String? previousPath,
    required String currentPath,
    required HomeView viewController,
  }) {
    if (previousPath == null || previousPath == currentPath) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final searchController = ref.read(searchProvider);
      if (searchController.text.isNotEmpty) {
        searchController.clear();
      }
      FocusManager.instance.primaryFocus?.unfocus();
      viewController.setQuery('');
    });
  }

  bool shouldShowMiniPlayer({
    required String? nowPlayingTitle,
    required Widget? child,
    required ViewState viewState,
    required String currentPath,
    required bool isSongPlaying,
  }) {
    final hasAudio = nowPlayingTitle != null && nowPlayingTitle.isNotEmpty;
    return hasAudio &&
        (child != null || viewState is! PlaySong) &&
        child is! SongWidget &&
        currentPath != '/playSong' &&
        // El mapa tiene su propia tarjeta para la emisora que suena; con una
        // cancion no muestra ningun control, asi que ahi si va el mini player.
        (currentPath != '/radio-map' || isSongPlaying);
  }

  bool shouldShowNowPlayingDetails({
    required Widget? child,
    required ViewState viewState,
    required String currentPath,
  }) {
    return currentPath == '/playSong' ||
        child is SongWidget ||
        (child == null && viewState is PlaySong);
  }
}
