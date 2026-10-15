// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorites_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FavoritesController)
final favoritesControllerProvider = FavoritesControllerProvider._();

final class FavoritesControllerProvider
    extends $NotifierProvider<FavoritesController, List<FavoriteSong>> {
  FavoritesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'favoritesControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$favoritesControllerHash();

  @$internal
  @override
  FavoritesController create() => FavoritesController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<FavoriteSong> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<FavoriteSong>>(value),
    );
  }
}

String _$favoritesControllerHash() =>
    r'bdb88262fe5a610debcccc5c45dd1af016796db8';

abstract class _$FavoritesController extends $Notifier<List<FavoriteSong>> {
  List<FavoriteSong> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<List<FavoriteSong>, List<FavoriteSong>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<FavoriteSong>, List<FavoriteSong>>,
              List<FavoriteSong>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
