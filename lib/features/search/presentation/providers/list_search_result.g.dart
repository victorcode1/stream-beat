// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_search_result.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(searchResultData)
final searchResultDataProvider = SearchResultDataFamily._();

final class SearchResultDataProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<YouTubeSearchSuggestion>>,
          List<YouTubeSearchSuggestion>,
          FutureOr<List<YouTubeSearchSuggestion>>
        >
    with
        $FutureModifier<List<YouTubeSearchSuggestion>>,
        $FutureProvider<List<YouTubeSearchSuggestion>> {
  SearchResultDataProvider._({
    required SearchResultDataFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'searchResultDataProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$searchResultDataHash();

  @override
  String toString() {
    return r'searchResultDataProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<YouTubeSearchSuggestion>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<YouTubeSearchSuggestion>> create(Ref ref) {
    final argument = this.argument as String;
    return searchResultData(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SearchResultDataProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$searchResultDataHash() => r'7789da9af2c1c52c81852d2e233e9724b6e42a89';

final class SearchResultDataFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<YouTubeSearchSuggestion>>,
          String
        > {
  SearchResultDataFamily._()
    : super(
        retry: null,
        name: r'searchResultDataProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  SearchResultDataProvider call(String search) =>
      SearchResultDataProvider._(argument: search, from: this);

  @override
  String toString() => r'searchResultDataProvider';
}
