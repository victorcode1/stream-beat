import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_account_repository.dart';
import 'package:flow_music/features/youtube_account/presentation/controllers/youtube_music_account_controller.dart';
import 'package:flow_music/features/youtube_account/presentation/widgets/connect_youtube_music_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _cookiesChannel = MethodChannel('streambeat/web_cookies');

/// Inicio de sesion de Google dentro de la app. Al volver a
/// music.youtube.com con la sesion iniciada lee la cookie de la vista web (por
/// el canal nativo, que tambien ve las HttpOnly) y conecta la cuenta.
const _loginUrl =
    'https://accounts.google.com/ServiceLogin?service=youtube&passive=true'
    '&continue=https%3A%2F%2Fmusic.youtube.com%2F';

/// Google rechaza el inicio de sesion si reconoce una vista web; con el
/// agente del navegador del sistema lo trata como uno mas.
String get _browserUserAgent => switch (defaultTargetPlatform) {
  TargetPlatform.android =>
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/136.0.0.0 Mobile Safari/537.36',
  TargetPlatform.macOS =>
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
        '(KHTML, like Gecko) Version/18.0 Safari/605.1.15',
  _ =>
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 '
        'Mobile/15E148 Safari/604.1',
};

/// El inicio de sesion integrado solo existe donde hay vista web y canal.
bool get supportsYouTubeMusicWebLogin =>
    !kIsWeb &&
    switch (defaultTargetPlatform) {
      TargetPlatform.iOS ||
      TargetPlatform.android ||
      TargetPlatform.macOS => true,
      _ => false,
    };

/// Abre el inicio de sesion. Devuelve true si la cuenta quedo conectada.
Future<bool> showYouTubeMusicLogin(BuildContext context) async {
  final connected = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const YouTubeMusicLoginPage()),
  );
  return connected ?? false;
}

class YouTubeMusicLoginPage extends ConsumerStatefulWidget {
  const YouTubeMusicLoginPage({super.key});

  @override
  ConsumerState<YouTubeMusicLoginPage> createState() =>
      _YouTubeMusicLoginPageState();
}

class _YouTubeMusicLoginPageState extends ConsumerState<YouTubeMusicLoginPage> {
  late final WebViewController _webView;
  bool _loading = true;
  bool _connecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _webView = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_browserUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => _setLoading(true),
          onPageFinished: _onPageFinished,
        ),
      )
      ..loadRequest(Uri.parse(_loginUrl));
  }

  void _setLoading(bool loading) {
    if (mounted && _loading != loading) setState(() => _loading = loading);
  }

  Future<void> _onPageFinished(String url) async {
    _setLoading(false);
    if (_connecting || Uri.tryParse(url)?.host != 'music.youtube.com') return;

    final header = await _cookiesChannel.invokeMethod<String>(
      'cookieHeader',
      'youtube.com',
    );
    // Sin SAPISID todavia no hay sesion (por ejemplo, si Google mando a
    // music.youtube.com sin iniciar sesion): se deja la pagina como esta.
    if (header == null || !header.contains('SAPISID=')) return;

    setState(() {
      _connecting = true;
      _error = null;
    });
    String? error;
    try {
      final accepted = await ref
          .read(youtubeMusicAccountControllerProvider.notifier)
          .connect(header);
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

  Future<void> _pasteCookie() async {
    final connected = await showConnectYouTubeMusicDialog(context);
    if (connected && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loading || _connecting;
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.yt_account_dialog_title.tr()),
        actions: [
          // Si Google bloquea la vista web queda la via manual.
          TextButton(
            onPressed: _connecting ? null : _pasteCookie,
            child: Text(LocaleKeys.yt_account_paste_cookie.tr()),
          ),
        ],
        bottom: busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: Column(
        children: [
          if (_error case final error?)
            MaterialBanner(
              content: Text(error),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() => _error = null);
                    _webView.loadRequest(Uri.parse(_loginUrl));
                  },
                  child: Text(LocaleKeys.retry.tr()),
                ),
              ],
            ),
          Expanded(child: WebViewWidget(controller: _webView)),
        ],
      ),
    );
  }
}

/// Borra la sesion de Google de la vista web, para que el proximo inicio de
/// sesion pida la cuenta otra vez.
Future<void> clearYouTubeMusicWebSession() async {
  if (!supportsYouTubeMusicWebLogin) return;
  await WebViewCookieManager().clearCookies();
}
