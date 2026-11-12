// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_mode_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controla el `ThemeMode` activo de la app.
///
/// Mantiene la preferencia en la caja `settings` de Hive y la expone como
/// estado de Riverpod para que `MaterialApp.router` pueda reaccionar.

@ProviderFor(ThemeModeController)
final themeModeControllerProvider = ThemeModeControllerProvider._();

/// Controla el `ThemeMode` activo de la app.
///
/// Mantiene la preferencia en la caja `settings` de Hive y la expone como
/// estado de Riverpod para que `MaterialApp.router` pueda reaccionar.
final class ThemeModeControllerProvider
    extends $NotifierProvider<ThemeModeController, ThemeMode> {
  /// Controla el `ThemeMode` activo de la app.
  ///
  /// Mantiene la preferencia en la caja `settings` de Hive y la expone como
  /// estado de Riverpod para que `MaterialApp.router` pueda reaccionar.
  ThemeModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeControllerHash();

  @$internal
  @override
  ThemeModeController create() => ThemeModeController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeMode>(value),
    );
  }
}

String _$themeModeControllerHash() =>
    r'd4006a3c8d8aea1232d6e6cde0da00ffd7a566d1';

/// Controla el `ThemeMode` activo de la app.
///
/// Mantiene la preferencia en la caja `settings` de Hive y la expone como
/// estado de Riverpod para que `MaterialApp.router` pueda reaccionar.

abstract class _$ThemeModeController extends $Notifier<ThemeMode> {
  ThemeMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ThemeMode, ThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ThemeMode, ThemeMode>,
              ThemeMode,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
