// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'autoplay_enabled_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Preferencia para avanzar a la siguiente emisora cuando una lista de radio
/// tiene más elementos disponibles.

@ProviderFor(AutoplayEnabledController)
final autoplayEnabledControllerProvider = AutoplayEnabledControllerProvider._();

/// Preferencia para avanzar a la siguiente emisora cuando una lista de radio
/// tiene más elementos disponibles.
final class AutoplayEnabledControllerProvider
    extends $NotifierProvider<AutoplayEnabledController, bool> {
  /// Preferencia para avanzar a la siguiente emisora cuando una lista de radio
  /// tiene más elementos disponibles.
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
    r'516b918abe2f798dbefdbde596b502df0237b789';

/// Preferencia para avanzar a la siguiente emisora cuando una lista de radio
/// tiene más elementos disponibles.

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
