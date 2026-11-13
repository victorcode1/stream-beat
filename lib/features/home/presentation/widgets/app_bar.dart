import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/audio/now_playing_provider.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/favorites/presentation/controllers/favorites_controller.dart';
import 'package:flow_music/features/home/presentation/controllers/home_app_bar_action_controller.dart';
import 'package:flow_music/features/home/presentation/controllers/home_app_bar_view_state.dart';
import 'package:flow_music/features/home/presentation/controllers/now_playing_details_view_state.dart';
import 'package:flow_music/features/home/presentation/widgets/home_app_bar_title.dart';
import 'package:flow_music/features/song/presentation/controllers/song_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// App bar principal de home.
///
/// Compone la vista y delega la lógica de acciones a su controller de presentación.
class AppAbarMain extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  final Function(String)? query;
  final Future Function() showSearch;
  final bool showNowPlayingDetails;
  final bool showNowPlayingTitle;

  /// El shell esta mostrando algo encima de las sugerencias (p. ej. la lista de
  /// una categoria). Sin esta flecha no habia como volver al home.
  final bool showBack;

  /// Que hacer al tocar la flecha cuando no estamos en el reproductor.
  final VoidCallback? onBack;

  const AppAbarMain({
    super.key,
    this.query,
    required this.showSearch,
    this.showNowPlayingDetails = false,
    this.showNowPlayingTitle = true,
    this.showBack = false,
    this.onBack,
  });

  @override
  ConsumerState<AppAbarMain> createState() => _AppAbarMainState();

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (showNowPlayingDetails ? 40 : 20));
}

class _AppAbarMainState extends ConsumerState<AppAbarMain> {
  @override
  Widget build(BuildContext context) {
    final songState = ref.watch(songController);
    final nowPlayingTitle = ref.watch(nowPlayingTitleProvider).asData?.value;
    final favorites = ref.watch(favoritesControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final actions = HomeAppBarActionController(ref: ref);
    final viewState = HomeAppBarViewState.fromSongState(
      songState: songState,
      nowPlayingTitle: nowPlayingTitle,
      showNowPlayingTitle: widget.showNowPlayingTitle,
    );
    final detailsState = NowPlayingDetailsViewState.fromPlayback(
      item: viewState.nowPlayingItem,
      isDownloaded: songState.hasDownloadedCurrentMedia,
      isOfflineSaved: songState.hasOfflineCurrentAudio,
      isLoading: songState.isLoading,
      isDownloading: songState.isDownloading,
      isSavingOffline: songState.isSavingOffline,
      downloadProgress: songState.downloadProgress,
      offlineProgress: songState.offlineProgress,
      isFavorite:
          viewState.nowPlayingItem.videoId.isNotEmpty &&
          favorites.any(
            (fav) => fav.videoId == viewState.nowPlayingItem.videoId,
          ),
    );

    return AppBar(
      // Transparente para integrarse con el fondo ambiente (gradiente teñido
      // por el acento); antes era un bloque solido que no combinaba con el
      // cuerpo.
      backgroundColor: Colors.transparent,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      // Sin drawer: la navegacion vive en la barra inferior. Solo mostramos el
      // boton de retroceso cuando estamos en el reproductor a pantalla completa.
      automaticallyImplyLeading: false,
      leading: widget.showNowPlayingDetails || widget.showBack
          ? IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: colorScheme.onSurface,
              ),
              onPressed: widget.showNowPlayingDetails
                  ? () => actions.handleBack(context)
                  : (widget.onBack ?? () => actions.handleBack(context)),
            )
          : null,
      title: widget.showNowPlayingDetails
          ? _NowPlayingDetailsBar(
              state: detailsState,
              onSelected: (action) => actions.handleNowPlayingMenuAction(
                context: context,
                action: action,
                item: detailsState.item,
              ),
            )
          : HomeAppBarTitle(
              titleText: viewState.titleText,
              hasNowPlaying: viewState.hasNowPlaying,
            ),
      actions: [
        if (viewState.playlistItem != null &&
            !widget.showNowPlayingDetails) ...[
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: colorScheme.surfaceContainerHighest,
            ),
            child: IconButton(
              tooltip: LocaleKeys.add_to_playlist.tr(),
              icon: Icon(
                Icons.playlist_add_rounded,
                color: colorScheme.onSurface,
                size: 22,
              ),
              onPressed: () => actions.addToPlaylist(
                context: context,
                audio: viewState.playlistItem!,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (!widget.showNowPlayingDetails) ...[
          // Buscador como icono cuadrado (diseno StreamBeat): abre la busqueda;
          // ya no hay campo de texto grande en el header.
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 20,
              tooltip: LocaleKeys.search.tr(),
              onPressed: widget.showSearch,
              icon: Icon(Icons.search_rounded, color: colorScheme.onSurface),
            ),
          ),
          const SizedBox(width: 10),
          const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _NowPlayingDetailsBar extends StatelessWidget {
  final NowPlayingDetailsViewState state;
  final ValueChanged<HomeAppBarMenuAction> onSelected;

  const _NowPlayingDetailsBar({required this.state, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Una sola linea, para que el rotulo quede a la altura de los botones.
        // Durante una descarga, el rotulo muestra su progreso.
        Expanded(child: _NowPlayingHeading(state: state)),
        // Accesos rapidos que antes iban en chips al pie del reproductor:
        // en la barra liberan espacio para la caratula.
        _NowPlayingBarAction(
          icon: state.item.isVideo
              ? Icons.videocam_rounded
              : Icons.videocam_outlined,
          tooltip: LocaleKeys.video.tr(),
          selected: state.item.isVideo,
          onPressed: () => onSelected(HomeAppBarMenuAction.toggleVideo),
        ),
        _NowPlayingBarAction(
          icon: Icons.queue_music_rounded,
          tooltip: LocaleKeys.queue.tr(),
          onPressed: () => onSelected(HomeAppBarMenuAction.queue),
        ),
        _NowPlayingBarAction(
          icon: Icons.ios_share_rounded,
          tooltip: LocaleKeys.share.tr(),
          onPressed: () => onSelected(HomeAppBarMenuAction.share),
        ),
        _NowPlayingMenuButton(state: state, onSelected: onSelected),
      ],
    );
  }
}

class _NowPlayingHeading extends StatelessWidget {
  final NowPlayingDetailsViewState state;

  const _NowPlayingHeading({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final transfer = state.transferStatus;
    final label = transfer?.label ?? LocaleKeys.playing.tr().toUpperCase();
    final color = transfer == null ? colors.onSurfaceVariant : colors.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final status in [?transfer, ...state.statusItems]) ...[
          Icon(status.icon, size: 14, color: colors.primary),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: transfer == null ? 1.5 : 0.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _NowPlayingBarAction extends StatelessWidget {
  const _NowPlayingBarAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: selected ? colors.primary : colors.onSurface),
    );
  }
}

class _NowPlayingMenuButton extends StatelessWidget {
  final NowPlayingDetailsViewState state;
  final ValueChanged<HomeAppBarMenuAction> onSelected;

  const _NowPlayingMenuButton({required this.state, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final downloadLabel = state.isDownloaded
        ? LocaleKeys.view_downloaded_file.tr()
        : state.item.isVideo
        ? LocaleKeys.download_video.tr()
        : LocaleKeys.download_audio.tr();
    final offlineLabel = state.isOfflineSaved
        ? LocaleKeys.remove_offline.tr()
        : LocaleKeys.save_offline.tr();

    return SizedBox(
      width: 38,
      height: 38,
      child: PopupMenuButton<HomeAppBarMenuAction>(
        tooltip: LocaleKeys.audio_tools.tr(),
        icon: Icon(Icons.more_vert_rounded, color: colors.onSurface),
        onSelected: onSelected,
        itemBuilder: (context) => [
          PopupMenuItem(
            value: HomeAppBarMenuAction.favorite,
            child: _NowPlayingMenuRow(
              icon: state.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: state.isFavorite
                  ? LocaleKeys.remove_from_favorites.tr()
                  : LocaleKeys.add_to_favorites.tr(),
            ),
          ),
          PopupMenuItem(
            value: HomeAppBarMenuAction.addToPlaylist,
            child: _NowPlayingMenuRow(
              icon: Icons.playlist_add_rounded,
              label: LocaleKeys.add_to_playlist.tr(),
            ),
          ),
          PopupMenuItem(
            value: HomeAppBarMenuAction.sleepTimer,
            child: _NowPlayingMenuRow(
              icon: Icons.bedtime_rounded,
              label: LocaleKeys.sleep_timer.tr(),
            ),
          ),
          PopupMenuItem(
            value: HomeAppBarMenuAction.audioTools,
            child: _NowPlayingMenuRow(
              icon: Icons.tune_rounded,
              label: LocaleKeys.audio_tools.tr(),
            ),
          ),
          if (!kIsWeb) ...[
            const PopupMenuDivider(),
            PopupMenuItem(
              value: HomeAppBarMenuAction.download,
              enabled: !state.isLoading,
              child: _NowPlayingMenuRow(
                icon: state.isDownloaded
                    ? Icons.folder_open_rounded
                    : Icons.download_rounded,
                label: downloadLabel,
              ),
            ),
            PopupMenuItem(
              value: HomeAppBarMenuAction.offline,
              enabled: !state.item.isVideo && !state.isLoading,
              child: _NowPlayingMenuRow(
                icon: state.isOfflineSaved
                    ? Icons.offline_pin_rounded
                    : Icons.offline_bolt_rounded,
                label: offlineLabel,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NowPlayingMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _NowPlayingMenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colors.primary),
        const SizedBox(width: 12),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
