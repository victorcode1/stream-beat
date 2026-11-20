import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_account_repository.dart';
import 'package:flow_music/features/youtube_account/presentation/controllers/youtube_music_account_controller.dart';
import 'package:flow_music/features/youtube_account/presentation/pages/youtube_music_login_page.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Conecta la cuenta: con el inicio de sesion integrado donde existe y, si
/// no, pegando la cookie.
Future<void> connectYouTubeMusic(BuildContext context) async {
  if (supportsYouTubeMusicWebLogin) {
    await showYouTubeMusicLogin(context);
  } else {
    await showConnectYouTubeMusicDialog(context);
  }
}

/// Pide el encabezado `Cookie` de music.youtube.com y lo valida con YouTube
/// antes de guardarlo. Devuelve true si la cuenta quedo conectada.
Future<bool> showConnectYouTubeMusicDialog(BuildContext context) async {
  final connected = await showDialog<bool>(
    context: context,
    builder: (_) => const _ConnectYouTubeMusicDialog(),
  );
  return connected ?? false;
}

class _ConnectYouTubeMusicDialog extends ConsumerStatefulWidget {
  const _ConnectYouTubeMusicDialog();

  @override
  ConsumerState<_ConnectYouTubeMusicDialog> createState() =>
      _ConnectYouTubeMusicDialogState();
}

class _ConnectYouTubeMusicDialogState
    extends ConsumerState<_ConnectYouTubeMusicDialog> {
  final _cookieController = TextEditingController();
  bool _connecting = false;
  String? _error;

  @override
  void dispose() {
    _cookieController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    String? error;
    try {
      final accepted = await ref
          .read(youtubeMusicAccountControllerProvider.notifier)
          .connect(_cookieController.text);
      if (!accepted) error = LocaleKeys.yt_account_invalid_cookie.tr();
    } on YouTubeMusicSessionExpired {
      error = LocaleKeys.yt_account_rejected.tr();
    } catch (_) {
      error = LocaleKeys.yt_account_load_error.tr();
    }
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _connecting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final localizations = MaterialLocalizations.of(context);

    return AlertDialog(
      title: Text(LocaleKeys.yt_account_dialog_title.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(LocaleKeys.yt_account_dialog_steps.tr()),
            const SizedBox(height: 12),
            Text(
              LocaleKeys.yt_account_dialog_warning.tr(),
              style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cookieController,
              enabled: !_connecting,
              minLines: 3,
              maxLines: 6,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: LocaleKeys.yt_account_cookie_label.tr(),
                errorText: _error,
                errorMaxLines: 3,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _connecting ? null : () => Navigator.of(context).pop(),
          child: Text(localizations.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _connecting ? null : _connect,
          child: _connecting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(LocaleKeys.yt_account_connect.tr()),
        ),
      ],
    );
  }
}
