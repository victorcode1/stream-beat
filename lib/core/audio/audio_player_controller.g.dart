// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_player_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AudioPlayerProvider)
final audioPlayerProviderProvider = AudioPlayerProviderProvider._();

final class AudioPlayerProviderProvider
    extends $NotifierProvider<AudioPlayerProvider, AudioPlayer> {
  AudioPlayerProviderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioPlayerProviderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioPlayerProviderHash();

  @$internal
  @override
  AudioPlayerProvider create() => AudioPlayerProvider();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioPlayer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioPlayer>(value),
    );
  }
}

String _$audioPlayerProviderHash() =>
    r'efaec593c18854bc970b8ec4b4af562947e380ad';

abstract class _$AudioPlayerProvider extends $Notifier<AudioPlayer> {
  AudioPlayer build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AudioPlayer, AudioPlayer>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AudioPlayer, AudioPlayer>,
              AudioPlayer,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
