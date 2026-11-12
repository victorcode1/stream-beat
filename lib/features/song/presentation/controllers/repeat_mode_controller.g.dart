// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'repeat_mode_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// When true, the current track loops instead of advancing through the
/// autoplay queue. Persisted in Hive so the user's choice survives restarts.

@ProviderFor(RepeatModeController)
final repeatModeControllerProvider = RepeatModeControllerProvider._();

/// When true, the current track loops instead of advancing through the
/// autoplay queue. Persisted in Hive so the user's choice survives restarts.
final class RepeatModeControllerProvider
    extends $NotifierProvider<RepeatModeController, bool> {
  /// When true, the current track loops instead of advancing through the
  /// autoplay queue. Persisted in Hive so the user's choice survives restarts.
  RepeatModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'repeatModeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$repeatModeControllerHash();

  @$internal
  @override
  RepeatModeController create() => RepeatModeController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$repeatModeControllerHash() =>
    r'c4411b56c393f53522feacea9caeb49f87941aa9';

/// When true, the current track loops instead of advancing through the
/// autoplay queue. Persisted in Hive so the user's choice survives restarts.

abstract class _$RepeatModeController extends $Notifier<bool> {
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
