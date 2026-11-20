import 'package:flow_music/features/autoplay/presentation/controllers/autoplay_queue_controller.dart';
import 'package:flow_music/features/home/presentation/controllers/home_view_controller.dart';
import 'package:flow_music/features/home/presentation/widgets/home_mobile_sections.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_library_parser.dart';
import 'package:flow_music/features/youtube_account/presentation/controllers/youtube_music_account_controller.dart';
import 'package:flow_music/features/youtube_account/presentation/pages/youtube_music_playlist_page.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Filas del Inicio de YouTube Music de la cuenta conectada, como slivers del
/// Inicio movil. Sin cuenta, cargando o con error no ocupa espacio.
class YouTubeMusicHomeShelves extends ConsumerWidget {
  const YouTubeMusicHomeShelves({super.key, required this.firstIndex});

  /// Posicion del primer encabezado, para seguir la secuencia de colores.
  final int firstIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelves = ref.watch(youtubeMusicHomeProvider).value ?? const [];
    if (shelves.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        for (final (offset, shelf) in shelves.indexed) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: HomeSectionHeader(
                title: shelf.title,
                index: firstIndex + offset,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: HomeCoverRow<YouTubeMusicHomeItem>(
              items: shelf.items,
              size: 148,
              title: (item) => item.title,
              subtitle: (item) => item.subtitle,
              artwork: (item) => item.thumbnailUrl,
              onTap: (item) => _open(context, ref, shelf, item),
            ),
          ),
        ],
      ],
    );
  }

  /// Una cancion suena con el resto de canciones de su fila en cola; una
  /// lista, album o mix abre sus canciones.
  void _open(
    BuildContext context,
    WidgetRef ref,
    YouTubeMusicHomeShelf shelf,
    YouTubeMusicHomeItem item,
  ) {
    final playlist = item.playlist;
    if (playlist != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => YouTubeMusicPlaylistPage(playlist: playlist),
        ),
      );
      return;
    }
    final song = item.song!;
    final songs = shelf.songs;
    final index = songs.indexWhere((s) => s.videoId == song.videoId);
    ref.read(autoplayQueueControllerProvider.notifier).enqueue(songs, index);
    ref.read(homeViewProvider.notifier).listen(song);
  }
}
