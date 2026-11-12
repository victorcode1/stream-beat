// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache_status_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Tracks whether the device has run out of room for the autoplay cache.
/// Once flipped, the autoplay queue stops trying to write further files and
/// the UI shows a one-shot dialog so the user knows playback will still work
/// — just without the prefetched local cache.

@ProviderFor(CacheStatusController)
final cacheStatusControllerProvider = CacheStatusControllerProvider._();

/// Tracks whether the device has run out of room for the autoplay cache.
/// Once flipped, the autoplay queue stops trying to write further files and
/// the UI shows a one-shot dialog so the user knows playback will still work
/// — just without the prefetched local cache.
final class CacheStatusControllerProvider
    extends $NotifierProvider<CacheStatusController, CacheStatus> {
  /// Tracks whether the device has run out of room for the autoplay cache.
  /// Once flipped, the autoplay queue stops trying to write further files and
  /// the UI shows a one-shot dialog so the user knows playback will still work
  /// — just without the prefetched local cache.
  CacheStatusControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cacheStatusControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cacheStatusControllerHash();

  @$internal
  @override
  CacheStatusController create() => CacheStatusController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CacheStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CacheStatus>(value),
    );
  }
}

String _$cacheStatusControllerHash() =>
    r'272751b1c6cdaf3b6533758f57720369999762db';

/// Tracks whether the device has run out of room for the autoplay cache.
/// Once flipped, the autoplay queue stops trying to write further files and
/// the UI shows a one-shot dialog so the user knows playback will still work
/// — just without the prefetched local cache.

abstract class _$CacheStatusController extends $Notifier<CacheStatus> {
  CacheStatus build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CacheStatus, CacheStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CacheStatus, CacheStatus>,
              CacheStatus,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
