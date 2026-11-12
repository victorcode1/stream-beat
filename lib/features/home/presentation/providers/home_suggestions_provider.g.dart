// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_suggestions_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Carga la lista de sugerencias iniciales para mostrar en `home` cuando no
/// hay query ni reproduccion activa.
///
/// Al abrir la app se pinta lo ultimo que quedo guardado en disco, para no
/// dejar al usuario mirando el loading. Si esa tanda ya paso su hora
/// ([homeSuggestionsCacheTtl]) se renueva en segundo plano y la pantalla se
/// actualiza sola cuando llega la nueva.
///
/// `keepAlive: true` para que la lista no se pida cada vez que el usuario
/// vuelva al estado `Suggested` despues de buscar o reproducir.

@ProviderFor(HomeSuggestions)
final homeSuggestionsProvider = HomeSuggestionsProvider._();

/// Carga la lista de sugerencias iniciales para mostrar en `home` cuando no
/// hay query ni reproduccion activa.
///
/// Al abrir la app se pinta lo ultimo que quedo guardado en disco, para no
/// dejar al usuario mirando el loading. Si esa tanda ya paso su hora
/// ([homeSuggestionsCacheTtl]) se renueva en segundo plano y la pantalla se
/// actualiza sola cuando llega la nueva.
///
/// `keepAlive: true` para que la lista no se pida cada vez que el usuario
/// vuelva al estado `Suggested` despues de buscar o reproducir.
final class HomeSuggestionsProvider
    extends $AsyncNotifierProvider<HomeSuggestions, HomeSuggestionsResult> {
  /// Carga la lista de sugerencias iniciales para mostrar en `home` cuando no
  /// hay query ni reproduccion activa.
  ///
  /// Al abrir la app se pinta lo ultimo que quedo guardado en disco, para no
  /// dejar al usuario mirando el loading. Si esa tanda ya paso su hora
  /// ([homeSuggestionsCacheTtl]) se renueva en segundo plano y la pantalla se
  /// actualiza sola cuando llega la nueva.
  ///
  /// `keepAlive: true` para que la lista no se pida cada vez que el usuario
  /// vuelva al estado `Suggested` despues de buscar o reproducir.
  HomeSuggestionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeSuggestionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeSuggestionsHash();

  @$internal
  @override
  HomeSuggestions create() => HomeSuggestions();
}

String _$homeSuggestionsHash() => r'8c598959abe93b463fb3ca244248da0bce3aa30d';

/// Carga la lista de sugerencias iniciales para mostrar en `home` cuando no
/// hay query ni reproduccion activa.
///
/// Al abrir la app se pinta lo ultimo que quedo guardado en disco, para no
/// dejar al usuario mirando el loading. Si esa tanda ya paso su hora
/// ([homeSuggestionsCacheTtl]) se renueva en segundo plano y la pantalla se
/// actualiza sola cuando llega la nueva.
///
/// `keepAlive: true` para que la lista no se pida cada vez que el usuario
/// vuelva al estado `Suggested` despues de buscar o reproducir.

abstract class _$HomeSuggestions extends $AsyncNotifier<HomeSuggestionsResult> {
  FutureOr<HomeSuggestionsResult> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<HomeSuggestionsResult>, HomeSuggestionsResult>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<HomeSuggestionsResult>,
                HomeSuggestionsResult
              >,
              AsyncValue<HomeSuggestionsResult>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
