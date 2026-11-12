// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_view_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HomeView)
final homeViewProvider = HomeViewProvider._();

final class HomeViewProvider extends $NotifierProvider<HomeView, ViewState> {
  HomeViewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeViewProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeViewHash();

  @$internal
  @override
  HomeView create() => HomeView();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ViewState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ViewState>(value),
    );
  }
}

String _$homeViewHash() => r'3839210246cb05aea3c5d1c08434a9b867fd351b';

abstract class _$HomeView extends $Notifier<ViewState> {
  ViewState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ViewState, ViewState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ViewState, ViewState>,
              ViewState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
