import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/theme/visual_style.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_account_repository.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_library_parser.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_sync.dart';
import 'package:flow_music/features/youtube_account/presentation/controllers/youtube_music_account_controller.dart';
import 'package:flow_music/features/youtube_account/presentation/controllers/youtube_music_sync_controller.dart';
import 'package:flow_music/features/youtube_account/presentation/pages/youtube_music_login_page.dart';
import 'package:flow_music/features/youtube_account/presentation/widgets/connect_youtube_music_dialog.dart';
import 'package:flow_music/features/youtube_account/presentation/widgets/youtube_music_avatar.dart';
import 'package:flow_music/features/youtube_account/presentation/widgets/youtube_music_sync_action.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hoja de la cuenta conectada: perfil, contadores, sincronizar, abrir el
/// canal y desconectar.
///
/// Jerarquia de superficies: la hoja es `surfaceContainer` y cada grupo una
/// tarjeta `surfaceContainerHigh` con el radio del estilo. Las filas van
/// transparentes dentro de su tarjeta (el `listTileTheme` global les pone un
/// fondo propio que aqui rompia el conjunto).
Future<void> showYouTubeMusicAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _AccountSheet(host: context),
  );
}

const _sidePadding = 20.0;
const _groupGap = 12.0;
const _actionIconSize = 36.0;

class _AccountSheet extends ConsumerWidget {
  const _AccountSheet({required this.host});

  /// Pantalla que abrio la hoja: sigue montada cuando la hoja se cierra, asi
  /// que los avisos y el inicio de sesion se muestran desde ella.
  final BuildContext host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(youtubeMusicAccountInfoProvider);
    final expired = info.error is YouTubeMusicSessionExpired;
    final account = info.value;
    final syncing = ref.watch(youtubeMusicSyncControllerProvider);
    final lastSync = ref.watch(youtubeLastSyncProvider);
    final colors = Theme.of(context).colorScheme;
    final hasChannel = account != null && account.handle.isNotEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          _sidePadding,
          0,
          _sidePadding,
          _sidePadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileHeader(account: account),
            const SizedBox(height: 24),
            if (expired) ...[
              _ExpiredCard(host: host),
            ] else ...[
              const _SheetGroup(child: _Stats()),
            ],
            const SizedBox(height: _groupGap),
            _SheetGroup(
              child: Column(
                children: [
                  _ActionRow(
                    icon: Icons.sync_rounded,
                    busy: syncing,
                    title: LocaleKeys.yt_sync_action.tr(),
                    subtitle: _lastSyncLabel(context, lastSync),
                    onTap: syncing || expired
                        ? null
                        : () {
                            // Se arranca antes de cerrar, mientras el ref
                            // sigue vivo.
                            syncYouTubeMusic(host, ref);
                            Navigator.of(context).pop();
                          },
                  ),
                  if (hasChannel) ...[
                    const _InsetDivider(),
                    _ActionRow(
                      icon: Icons.open_in_new_rounded,
                      title: LocaleKeys.yt_account_open_channel.tr(),
                      onTap: () => launchUrl(
                        Uri.https('www.youtube.com', '/${account.handle}'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: _groupGap),
            _SheetGroup(
              child: _ActionRow(
                icon: Icons.logout_rounded,
                color: colors.error,
                title: LocaleKeys.yt_account_disconnect.tr(),
                onTap: () => _confirmDisconnect(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _lastSyncLabel(BuildContext context, DateTime? lastSync) {
    if (lastSync == null) return LocaleKeys.yt_sync_never.tr();
    final format = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).add_jm();
    return LocaleKeys.yt_sync_last.tr(args: [format.format(lastSync)]);
  }

  Future<void> _confirmDisconnect(BuildContext context, WidgetRef ref) async {
    final localizations = MaterialLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(LocaleKeys.yt_account_disconnect_confirm_title.tr()),
          content: Text(LocaleKeys.yt_account_disconnect_confirm_body.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(localizations.cancelButtonLabel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(LocaleKeys.yt_account_disconnect.tr()),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    // El ref de la hoja deja de valer al cerrarla: se toma antes.
    final account = ref.read(youtubeMusicAccountControllerProvider.notifier);
    Navigator.of(context).pop();
    await account.disconnect();
    await clearYouTubeMusicWebSession();
  }
}

/// Foto con un aro fino del acento, nombre, usuario, correo y Premium.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.account});

  final YouTubeMusicAccountInfo? account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final account = this.account;
    final secondary = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.primary, width: 2),
          ),
          child: YouTubeMusicAvatar(
            size: 72,
            connected: true,
            account: account,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          account?.name ?? LocaleKeys.yt_account_title.tr(),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        if (account != null && account.handle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(account.handle, style: secondary),
        ],
        if (account != null && account.email.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            account.email,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
        if (account?.hasPremium ?? false) ...[
          const SizedBox(height: 12),
          const _PremiumBadge(),
        ],
      ],
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              size: 16,
              color: colors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              LocaleKeys.yt_account_premium.tr(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de un grupo de la hoja: un tono por encima del fondo, con el radio
/// del estilo activo.
class _SheetGroup extends StatelessWidget {
  const _SheetGroup({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = context.styleTokens.cardRadius.clamp(12.0, 24.0);
    final colors = Theme.of(context).colorScheme;
    // En el tema claro los dos tonos de superficie casi se confunden: un
    // contorno finisimo marca el borde de la tarjeta sin agregar otro color.
    return Material(
      color: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(
          color: colors.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Fila de accion transparente con el icono en un circulo suave.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.color,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  /// Color del icono y del texto; por defecto el acento y `onSurface`.
  final Color? color;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tint = color ?? colors.primary;
    final enabled = onTap != null;
    final subtitle = this.subtitle;

    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: enabled || busy ? 1 : 0.5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: _actionIconSize,
                height: _actionIconSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tint.withValues(alpha: 0.12),
                ),
                alignment: Alignment.center,
                child: busy
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: tint,
                        ),
                      )
                    : Icon(icon, size: 20, color: tint),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: color ?? colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Separador fino que empieza donde empieza el texto de las filas.
class _InsetDivider extends StatelessWidget {
  const _InsetDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 16 + _actionIconSize + 16,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.6),
    );
  }
}

class _ExpiredCard extends StatelessWidget {
  const _ExpiredCard({required this.host});

  final BuildContext host;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return _SheetGroup(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.lock_clock_rounded, color: colors.error),
            const SizedBox(height: 8),
            Text(
              LocaleKeys.yt_account_session_expired.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              LocaleKeys.yt_account_session_expired_hint.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                connectYouTubeMusic(host);
              },
              child: Text(LocaleKeys.yt_account_sign_in_again.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Listas, «Me gusta» y artistas seguidos. Listas y «Me gusta» salen de la
/// copia guardada en la ultima sincronizacion; los artistas se piden a
/// YouTube al abrir la hoja.
class _Stats extends ConsumerWidget {
  const _Stats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(youtubeLibraryProvider);
    final synced = ref.watch(youtubeLastSyncProvider) != null;
    final artists = ref.watch(youtubeSubscribedArtistsCountProvider);
    final divider = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.6);

    final liked = library
        .where((saved) => saved.playlist.id == youtubeLikedPlaylistId)
        .firstOrNull;
    final playlists = library
        .where((saved) => saved.playlist.id != youtubeLikedPlaylistId)
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _Stat(
              value: synced ? '$playlists' : '—',
              label: LocaleKeys.yt_account_stat_playlists.tr(),
            ),
            VerticalDivider(width: 1, thickness: 0.5, color: divider),
            _Stat(
              value: synced && liked != null ? '${liked.tracks.length}' : '—',
              label: LocaleKeys.yt_account_stat_likes.tr(),
            ),
            VerticalDivider(width: 1, thickness: 0.5, color: divider),
            _Stat(
              value: artists.when(
                data: (count) => count == null ? '—' : '$count',
                loading: () => '…',
                error: (_, _) => '—',
              ),
              label: LocaleKeys.yt_account_stat_artists.tr(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
