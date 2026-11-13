import 'package:flow_music/core/connectivity/offline_banner.dart';
import 'package:flow_music/features/home/presentation/controllers/home_view_controller.dart';
import 'package:flow_music/features/home/presentation/widgets/home_suggestions.dart';
import 'package:flow_music/features/search/presentation/pages/list_search.dart';
import 'package:flow_music/features/search/presentation/widgets/list_songs.dart';
import 'package:flow_music/features/song/presentation/pages/song.dart';
import 'package:flutter/material.dart';

/// Renderiza el cuerpo central del home segun el estado actual de navegacion.
class HomePageContent extends StatelessWidget {
  const HomePageContent({
    super.key,
    required this.child,
    required this.viewState,
    required this.viewController,
  });

  final Widget? child;
  final ViewState viewState;
  final HomeView viewController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const OfflineBanner(),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) {
              return SizeTransition(sizeFactor: animation, child: child);
            },
            child: child ?? _buildView(),
          ),
        ),
      ],
    );
  }

  Widget _buildView() {
    return switch (viewState) {
      SuggestedListSearchListSong(:final data) => SuggestedListSearch(
        searchQuery: data,
      ),
      Suggested() => const HomeSuggestions(),
      ListSong(:final query) => ListSongs(
        data: query ?? '',
        listen: viewController.listen,
      ),
      PlaySong(:final queryParameters) => SongWidget(
        data: queryParameters ?? {},
      ),
    };
  }
}
