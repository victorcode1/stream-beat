// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_quick_search_data.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SearchDataReq)
final searchDataReqProvider = SearchDataReqFamily._();

final class SearchDataReqProvider
    extends
        $AsyncNotifierProvider<SearchDataReq, List<YouTubeSearchSuggestion>> {
  SearchDataReqProvider._({
    required SearchDataReqFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'searchDataReqProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$searchDataReqHash();

  @override
  String toString() {
    return r'searchDataReqProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SearchDataReq create() => SearchDataReq();

  @override
  bool operator ==(Object other) {
    return other is SearchDataReqProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$searchDataReqHash() => r'8dfd8ff37cbc3e46c875db01593e46cd95270ba7';

final class SearchDataReqFamily extends $Family
    with
        $ClassFamilyOverride<
          SearchDataReq,
          AsyncValue<List<YouTubeSearchSuggestion>>,
          List<YouTubeSearchSuggestion>,
          FutureOr<List<YouTubeSearchSuggestion>>,
          String?
        > {
  SearchDataReqFamily._()
    : super(
        retry: null,
        name: r'searchDataReqProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SearchDataReqProvider call({required String? search}) =>
      SearchDataReqProvider._(argument: search, from: this);

  @override
  String toString() => r'searchDataReqProvider';
}

abstract class _$SearchDataReq
    extends $AsyncNotifier<List<YouTubeSearchSuggestion>> {
  late final _$args = ref.$arg as String?;
  String? get search => _$args;

  FutureOr<List<YouTubeSearchSuggestion>> build({required String? search});
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<YouTubeSearchSuggestion>>,
              List<YouTubeSearchSuggestion>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<YouTubeSearchSuggestion>>,
                List<YouTubeSearchSuggestion>
              >,
              AsyncValue<List<YouTubeSearchSuggestion>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(search: _$args));
  }
}
