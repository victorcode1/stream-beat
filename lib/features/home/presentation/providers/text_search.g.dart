// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'text_search.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Search)
final searchProvider = SearchProvider._();

final class SearchProvider
    extends $NotifierProvider<Search, Raw<TextEditingController>> {
  SearchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchHash();

  @$internal
  @override
  Search create() => Search();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Raw<TextEditingController> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Raw<TextEditingController>>(value),
    );
  }
}

String _$searchHash() => r'65780cd4fd7bb7b783f40f6c06f24a4a3167c558';

abstract class _$Search extends $Notifier<Raw<TextEditingController>> {
  Raw<TextEditingController> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<Raw<TextEditingController>, Raw<TextEditingController>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Raw<TextEditingController>,
                Raw<TextEditingController>
              >,
              Raw<TextEditingController>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
