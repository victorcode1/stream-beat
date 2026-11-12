// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routes.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Route)
final routeProvider = RouteProvider._();

final class RouteProvider extends $NotifierProvider<Route, GoRouter> {
  RouteProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'routeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$routeHash();

  @$internal
  @override
  Route create() => Route();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$routeHash() => r'218cfe184b606cad9e5983abecf505041d6c5c90';

abstract class _$Route extends $Notifier<GoRouter> {
  GoRouter build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<GoRouter, GoRouter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GoRouter, GoRouter>,
              GoRouter,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
