// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_suggestions_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(homeSuggestions)
final homeSuggestionsProvider = HomeSuggestionsProvider._();

final class HomeSuggestionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<HomeRadioSuggestions>,
          HomeRadioSuggestions,
          FutureOr<HomeRadioSuggestions>
        >
    with
        $FutureModifier<HomeRadioSuggestions>,
        $FutureProvider<HomeRadioSuggestions> {
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
  $FutureProviderElement<HomeRadioSuggestions> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<HomeRadioSuggestions> create(Ref ref) {
    return homeSuggestions(ref);
  }
}

String _$homeSuggestionsHash() => r'ccd38aacf76b1c6ba4cba833c988f8e2f90b7e83';
