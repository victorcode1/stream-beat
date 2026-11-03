import 'dart:async';

import 'package:flow_music/core/config/app_environment.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final exitAdControllerProvider = Provider<ExitAdController>((ref) {
  final controller = ExitAdController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// Keeps one 300x250 banner ready for the exit dialog.
///
/// The ad is preloaded so the dialog never changes size after it opens: a
/// banner that appears late could move the buttons under the user's finger.
class ExitAdController {
  ExitAdController({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const _maxAge = Duration(minutes: 55);
  static const _retryDelay = Duration(minutes: 1);

  final DateTime Function() _now;
  BannerAd? _ad;
  DateTime? _loadedAt;
  DateTime? _nextAttemptAt;

  void preload() {
    if (_ad != null) {
      final loadedAt = _loadedAt;
      if (loadedAt == null || _now().difference(loadedAt) < _maxAge) return;
      _discard();
    }
    final adUnitId = AppEnvironment.admobBannerId;
    final nextAttemptAt = _nextAttemptAt;
    if (adUnitId.isEmpty ||
        (nextAttemptAt != null && _now().isBefore(nextAttemptAt))) {
      return;
    }
    final ad = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.mediumRectangle,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (identical(_ad, ad)) _loadedAt = _now();
        },
        onAdFailedToLoad: (ad, _) => _failed(ad),
      ),
    );
    _ad = ad;
    unawaited(ad.load().catchError((Object _) => _failed(ad)));
  }

  /// Hands over a loaded, fresh ad. The caller must dispose it after showing.
  BannerAd? takeLoaded() {
    final ad = _ad;
    final loadedAt = _loadedAt;
    if (ad == null ||
        loadedAt == null ||
        _now().difference(loadedAt) >= _maxAge) {
      return null;
    }
    _ad = null;
    _loadedAt = null;
    return ad;
  }

  void _failed(Ad ad) {
    unawaited(ad.dispose());
    if (!identical(_ad, ad)) return;
    _ad = null;
    _loadedAt = null;
    _nextAttemptAt = _now().add(_retryDelay);
  }

  void _discard() {
    unawaited(_ad?.dispose());
    _ad = null;
    _loadedAt = null;
  }

  void dispose() => _discard();
}
