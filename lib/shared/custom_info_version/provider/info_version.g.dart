// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'info_version.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(InfoVersion)
final infoVersionProvider = InfoVersionProvider._();

final class InfoVersionProvider
    extends $NotifierProvider<InfoVersion, InfoModel> {
  InfoVersionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'infoVersionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$infoVersionHash();

  @$internal
  @override
  InfoVersion create() => InfoVersion();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InfoModel value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InfoModel>(value),
    );
  }
}

String _$infoVersionHash() => r'd2ccd55f43024edaa15e4b68add1c936d06e17c9';

abstract class _$InfoVersion extends $Notifier<InfoModel> {
  InfoModel build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<InfoModel, InfoModel>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<InfoModel, InfoModel>,
              InfoModel,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
