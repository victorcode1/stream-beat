// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'autoplay_enabled_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Boolean preference: when true, after a tapped search result finishes the
/// app auto-advances through the remaining results (prefetched in parallel).

@ProviderFor(AutoplayEnabledController)
final autoplayEnabledControllerProvider = AutoplayEnabledControllerProvider._();

/// Boolean preference: when true, after a tapped search result finishes the
/// app auto-advances through the remaining results (prefetched in parallel).
final class AutoplayEnabledControllerProvider
    extends $NotifierProvider<AutoplayEnabledController, bool> {
  /// Boolean preference: when true, after a tapped search result finishes the
  /// app auto-advances through the remaining results (prefetched in parallel).
  AutoplayEnabledControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'autoplayEnabledControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$autoplayEnabledControllerHash();

  @$internal
  @override
  AutoplayEnabledController create() => AutoplayEnabledController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$autoplayEnabledControllerHash() =>
    r'725d3641dd1443031bab070a22cc0102e14ed4a9';

/// Boolean preference: when true, after a tapped search result finishes the
/// app auto-advances through the remaining results (prefetched in parallel).

abstract class _$AutoplayEnabledController extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
