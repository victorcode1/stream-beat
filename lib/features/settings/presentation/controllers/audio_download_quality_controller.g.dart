// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_download_quality_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AudioDownloadQualityController)
final audioDownloadQualityControllerProvider =
    AudioDownloadQualityControllerProvider._();

final class AudioDownloadQualityControllerProvider
    extends
        $NotifierProvider<
          AudioDownloadQualityController,
          AudioDownloadQuality
        > {
  AudioDownloadQualityControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioDownloadQualityControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioDownloadQualityControllerHash();

  @$internal
  @override
  AudioDownloadQualityController create() => AudioDownloadQualityController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioDownloadQuality value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioDownloadQuality>(value),
    );
  }
}

String _$audioDownloadQualityControllerHash() =>
    r'25cd4438a5d4866d695f76255be3d85a4e79ca19';

abstract class _$AudioDownloadQualityController
    extends $Notifier<AudioDownloadQuality> {
  AudioDownloadQuality build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AudioDownloadQuality, AudioDownloadQuality>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AudioDownloadQuality, AudioDownloadQuality>,
              AudioDownloadQuality,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
