import 'dart:async';

import 'package:flow_music/core/config/app_environment.dart';
import 'package:flow_music/features/monetization/domain/services/ad_visibility_policy.dart';
import 'package:flow_music/features/monetization/presentation/providers/ad_providers.dart';
import 'package:flow_music/features/monetization/presentation/providers/monetization_providers.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Un banner adaptable anclado, separado de los controles. Escuchar no lo
/// oculta; pasar a segundo plano libera el anuncio sin tocar la sesion de audio.
///
/// El tamano se resuelve antes de pedir el anuncio para reservar su altura y
/// que los controles no se desplacen al llegar.
class RespectfulBannerSlot extends ConsumerStatefulWidget {
  const RespectfulBannerSlot({super.key});

  @override
  ConsumerState<RespectfulBannerSlot> createState() =>
      _RespectfulBannerSlotState();
}

class _RespectfulBannerSlotState extends ConsumerState<RespectfulBannerSlot>
    with WidgetsBindingObserver {
  late bool _foreground;
  int? _sizeWidth;
  AdSize? _size;

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground != foreground) setState(() => _foreground = foreground);
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(subscriptionAccessProvider).value;
    if (access == null ||
        !AdVisibilityPolicy.shouldShow(
          access: access,
          adsSupported: AppEnvironment.supportsNativeMonetization,
        )) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.truncate();
        if (width < AdSize.banner.width) return const SizedBox.shrink();
        if (_sizeWidth != width) _resolveSize(width);
        final size = _size;
        // Reservar altura antes de cargar evita desplazar los botones al llegar
        // el anuncio. El espacio se conserva al abrir/cerrar otra aplicacion.
        return SizedBox(
          height: (size?.height ?? AdSize.banner.height) + 24.0,
          child: _foreground && size != null
              ? _AnchoredBanner(key: ValueKey(size), size: size)
              : null,
        );
      },
    );
  }

  void _resolveSize(int width) {
    _sizeWidth = width;
    unawaited(
      AdSize.getLargeAnchoredAdaptiveBannerAdSize(width)
          .then<AdSize?>((size) => size)
          .catchError((Object _) => null)
          .then((size) {
            if (!mounted || _sizeWidth != width) return;
            // Sin tamano adaptable, el banner estandar mantiene el ingreso.
            setState(() => _size = size ?? AdSize.banner);
          }),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class _AnchoredBanner extends ConsumerStatefulWidget {
  const _AnchoredBanner({required this.size, super.key});

  final AdSize size;

  @override
  ConsumerState<_AnchoredBanner> createState() => _AnchoredBannerState();
}

class _AnchoredBannerState extends ConsumerState<_AnchoredBanner>
    with WidgetsBindingObserver {
  BannerAd? _banner;
  bool _loaded = false;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      return;
    }
    // En paused Flutter puede no dibujar otro frame: liberar el recurso nativo
    // aqui, sin esperar a que el padre retire este widget.
    _retry?.cancel();
    _retry = null;
    final banner = _banner;
    _banner = null;
    _loaded = false;
    unawaited(banner?.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final consent = ref.watch(canRequestAdsProvider);
    if (consent.value != true ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return const SizedBox.shrink();
    }
    if (_banner == null && _retry == null) {
      // La referencia se asigna inmediatamente para no duplicar solicitudes.
      _load();
    }
    final banner = _banner;
    if (!_loaded || banner == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: widget.size.width.toDouble(),
          height: widget.size.height.toDouble(),
          child: AdWidget(ad: banner),
        ),
      ),
    );
  }

  void _load() {
    final banner = BannerAd(
      adUnitId: AppEnvironment.admobBannerId,
      request: const AdRequest(),
      size: widget.size,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted || !identical(_banner, ad)) return;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) => _failed(ad),
      ),
    );
    _banner = banner;
    unawaited(banner.load().catchError((Object error) => _failed(banner)));
  }

  void _failed(Ad ad) {
    if (!mounted || !identical(_banner, ad)) return;
    unawaited(ad.dispose());
    _banner = null;
    _retry = Timer(const Duration(minutes: 1), () {
      _retry = null;
      if (mounted) setState(() {});
    });
    setState(() => _loaded = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retry?.cancel();
    unawaited(_banner?.dispose());
    super.dispose();
  }
}
