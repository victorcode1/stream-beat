import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/youtube_account/presentation/controllers/youtube_music_account_controller.dart';
import 'package:flow_music/features/youtube_account/presentation/widgets/connect_youtube_music_dialog.dart';
import 'package:flow_music/features/youtube_account/presentation/widgets/youtube_music_account_sheet.dart';
import 'package:flow_music/features/youtube_account/presentation/widgets/youtube_music_avatar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Boton de cuenta junto al titulo de la app: sin sesion invita a iniciarla;
/// con sesion muestra la foto de la cuenta y abre sus opciones.
class YouTubeMusicAccountButton extends ConsumerWidget {
  const YouTubeMusicAccountButton({super.key});

  static const _size = 36.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // En web el navegador no deja enviar la cookie de sesion.
    if (kIsWeb) return const SizedBox.shrink();

    final connected = ref.watch(youtubeMusicAccountControllerProvider) != null;
    final account = connected
        ? ref.watch(youtubeMusicAccountInfoProvider).value
        : null;

    return Tooltip(
      message: connected
          ? account?.name ?? LocaleKeys.yt_account_title.tr()
          : LocaleKeys.yt_account_connect.tr(),
      child: InkResponse(
        radius: _size * 0.7,
        onTap: () => connected
            ? showYouTubeMusicAccountSheet(context)
            : connectYouTubeMusic(context),
        child: YouTubeMusicAvatar(
          size: _size,
          connected: connected,
          account: account,
        ),
      ),
    );
  }
}
