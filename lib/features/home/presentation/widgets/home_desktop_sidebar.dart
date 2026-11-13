import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/routes/routes.dart';
import 'package:flow_music/core/theme/desktop_theme.dart';
import 'package:flow_music/core/theme/flow_cover_gradients.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/library/presentation/pages/library_playlist_detail_page.dart';
import 'package:flow_music/features/playlists/data/playlist.dart';
import 'package:flow_music/features/playlists/presentation/controllers/playlists_controller.dart';
import 'package:flow_music/features/playlists/presentation/widgets/playlist_actions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Sidebar fija para la variante desktop del home.
///
/// Sigue el riel del mockup "StreamBeat — Rediseño": navegacion arriba, las
/// playlists del usuario en medio (scrollean cuando no caben) y Configuracion
/// anclada abajo.
class HomeDesktopSidebar extends ConsumerWidget {
  const HomeDesktopSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final route = ref.read(routeProvider);
    final currentPath = GoRouterState.of(context).uri.path;
    final playlists = ref.watch(playlistsControllerProvider);

    return Container(
      width: FlowDesktopTheme.sidebarWidth,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border(right: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HomeDesktopNavItem(
                icon: Icons.home_rounded,
                label: LocaleKeys.home.tr(),
                selected: currentPath == '/home' || currentPath == '/playSong',
                onTap: () => route.go('/home'),
              ),
              _HomeDesktopNavItem(
                icon: Icons.library_music_rounded,
                label: LocaleKeys.library.tr(),
                selected: currentPath == '/library',
                onTap: () => route.go('/library'),
              ),
              _HomeDesktopNavItem(
                icon: Icons.favorite_rounded,
                label: LocaleKeys.favorites.tr(),
                selected: currentPath == '/favorites',
                onTap: () => route.go('/favorites'),
              ),
              _HomeDesktopNavItem(
                icon: Icons.radio_rounded,
                label: LocaleKeys.radio.tr(),
                selected: currentPath == '/radio',
                onTap: () => route.go('/radio'),
              ),
              _HomeDesktopNavItem(
                icon: Icons.travel_explore_rounded,
                label: LocaleKeys.radio_map_explorer.tr(),
                selected: currentPath == '/radio-map',
                onTap: () => route.go('/radio-map'),
              ),
              const _SidebarDivider(),
              Expanded(
                child: _SidebarPlaylists(
                  playlists: playlists,
                  onOpenLibrary: () => route.go('/library'),
                ),
              ),
              const _SidebarDivider(),
              _HomeDesktopNavItem(
                icon: Icons.settings_rounded,
                label: LocaleKeys.settings.tr(),
                selected: currentPath == '/settings',
                onTap: () => route.go('/settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hairline de separacion entre bloques del riel.
class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

/// Bloque "Tus playlists" del riel: titulo de seccion y las listas del usuario.
class _SidebarPlaylists extends StatelessWidget {
  const _SidebarPlaylists({
    required this.playlists,
    required this.onOpenLibrary,
  });

  final List<Playlist> playlists;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Text(
            LocaleKeys.your_playlists.tr(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
              color: FlowDesktopTheme.faint(colors),
            ),
          ),
        ),
        Expanded(
          child: playlists.isEmpty
              // El riel vacio invita a crear, no se queda en blanco.
              ? _EmptyPlaylists(onTap: onOpenLibrary)
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    return _SidebarPlaylistRow(playlist: playlist);
                  },
                ),
        ),
      ],
    );
  }
}

class _EmptyPlaylists extends StatelessWidget {
  const _EmptyPlaylists({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Align(
      alignment: Alignment.topCenter,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.add_rounded,
                size: 18,
                color: FlowDesktopTheme.faint(colors),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  LocaleKeys.create_playlist.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FlowDesktopTheme.faint(colors),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de playlist del riel: cubierta de degradado, nombre y conteo.
class _SidebarPlaylistRow extends StatelessWidget {
  const _SidebarPlaylistRow({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  LibraryPlaylistDetailPage(playlistId: playlist.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: FlowCoverGradients.of(playlist.id),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                      Text(
                        songCountLabel(playlist.itemCount),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: FlowDesktopTheme.faint(colors),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Item navegable de la sidebar desktop del home.
class _HomeDesktopNavItem extends StatelessWidget {
  const _HomeDesktopNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 15,
                      color: selected
                          ? colors.primary
                          : colors.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
