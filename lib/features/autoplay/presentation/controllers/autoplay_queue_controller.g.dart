// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'autoplay_queue_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the search-results queue and pre-resolved audio URLs / cached files.
///
/// When a search result is tapped, the parent calls [enqueue] with the full
/// result list and the tapped index. The queue keeps the tapped track as
/// `current` and the surrounding tracks as `played` (before) and `upcoming`
/// (after), then keeps a rolling background prefetch running over the head of
/// the queue so next/prev navigation is instant.
///
/// El relleno automatico se ancla en la cancion que el usuario toco: pide los
/// "relacionados" de YouTube (el mismo pozo del mix) para no salirse de esa
/// linea musical, y descarta en toda la sesion lo que ya sono o ya esta en la
/// cola para no repetir pistas.

@ProviderFor(AutoplayQueueController)
final autoplayQueueControllerProvider = AutoplayQueueControllerProvider._();

/// Holds the search-results queue and pre-resolved audio URLs / cached files.
///
/// When a search result is tapped, the parent calls [enqueue] with the full
/// result list and the tapped index. The queue keeps the tapped track as
/// `current` and the surrounding tracks as `played` (before) and `upcoming`
/// (after), then keeps a rolling background prefetch running over the head of
/// the queue so next/prev navigation is instant.
///
/// El relleno automatico se ancla en la cancion que el usuario toco: pide los
/// "relacionados" de YouTube (el mismo pozo del mix) para no salirse de esa
/// linea musical, y descarta en toda la sesion lo que ya sono o ya esta en la
/// cola para no repetir pistas.
final class AutoplayQueueControllerProvider
    extends $NotifierProvider<AutoplayQueueController, AutoplayQueueState> {
  /// Holds the search-results queue and pre-resolved audio URLs / cached files.
  ///
  /// When a search result is tapped, the parent calls [enqueue] with the full
  /// result list and the tapped index. The queue keeps the tapped track as
  /// `current` and the surrounding tracks as `played` (before) and `upcoming`
  /// (after), then keeps a rolling background prefetch running over the head of
  /// the queue so next/prev navigation is instant.
  ///
  /// El relleno automatico se ancla en la cancion que el usuario toco: pide los
  /// "relacionados" de YouTube (el mismo pozo del mix) para no salirse de esa
  /// linea musical, y descarta en toda la sesion lo que ya sono o ya esta en la
  /// cola para no repetir pistas.
  AutoplayQueueControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'autoplayQueueControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$autoplayQueueControllerHash();

  @$internal
  @override
  AutoplayQueueController create() => AutoplayQueueController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AutoplayQueueState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AutoplayQueueState>(value),
    );
  }
}

String _$autoplayQueueControllerHash() =>
    r'f3e90b3bbe99647810412f46ebcbd54ec02999e2';

/// Holds the search-results queue and pre-resolved audio URLs / cached files.
///
/// When a search result is tapped, the parent calls [enqueue] with the full
/// result list and the tapped index. The queue keeps the tapped track as
/// `current` and the surrounding tracks as `played` (before) and `upcoming`
/// (after), then keeps a rolling background prefetch running over the head of
/// the queue so next/prev navigation is instant.
///
/// El relleno automatico se ancla en la cancion que el usuario toco: pide los
/// "relacionados" de YouTube (el mismo pozo del mix) para no salirse de esa
/// linea musical, y descarta en toda la sesion lo que ya sono o ya esta en la
/// cola para no repetir pistas.

abstract class _$AutoplayQueueController extends $Notifier<AutoplayQueueState> {
  AutoplayQueueState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AutoplayQueueState, AutoplayQueueState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AutoplayQueueState, AutoplayQueueState>,
              AutoplayQueueState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
