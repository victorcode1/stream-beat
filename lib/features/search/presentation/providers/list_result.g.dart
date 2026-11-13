// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_result.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(searchData)
final searchDataProvider = SearchDataProvider._();

final class SearchDataProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<YouTubeSearchSuggestion>>,
          List<YouTubeSearchSuggestion>,
          FutureOr<List<YouTubeSearchSuggestion>>
        >
    with
        $FutureModifier<List<YouTubeSearchSuggestion>>,
        $FutureProvider<List<YouTubeSearchSuggestion>> {
  SearchDataProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchDataProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchDataHash();

  @$internal
  @override
  $FutureProviderElement<List<YouTubeSearchSuggestion>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<YouTubeSearchSuggestion>> create(Ref ref) {
    return searchData(ref);
  }
}

String _$searchDataHash() => r'170f5422afdcf0cf283c27fb211f16450ddcf4db';
