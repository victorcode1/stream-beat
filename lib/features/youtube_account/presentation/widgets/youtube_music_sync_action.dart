import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_account_repository.dart';
import 'package:flow_music/features/youtube_account/presentation/controllers/youtube_music_sync_controller.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Sincroniza con YouTube Music y avisa del resultado con un mensaje abajo.
///
/// Se lee el controlador antes de esperar nada: quien llama puede ser una
/// hoja que se cierra en ese momento y cuyo `ref` deja de valer.
Future<void> syncYouTubeMusic(BuildContext context, WidgetRef ref) {
  return _sync(
    ScaffoldMessenger.maybeOf(context),
    ref.read(youtubeMusicSyncControllerProvider.notifier),
  );
}

Future<void> _sync(
  ScaffoldMessengerState? messenger,
  YouTubeMusicSyncController controller,
) async {
  messenger?.showSnackBar(
    SnackBar(
      content: Text(LocaleKeys.yt_sync_running.tr()),
      duration: const Duration(minutes: 10),
    ),
  );
  String message;
  try {
    final summary = await controller.sync();
    message = summary == null
        ? LocaleKeys.yt_sync_running.tr()
        : LocaleKeys.yt_sync_done.tr(
            args: [
              '${summary.playlistsSaved}',
              '${summary.favoritesAdded}',
              '${summary.changesSent}',
            ],
          );
  } on YouTubeMusicSessionExpired {
    message = LocaleKeys.yt_account_rejected.tr();
  } catch (_) {
    message = LocaleKeys.yt_sync_failed.tr();
  }
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
