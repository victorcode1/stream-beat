import 'dart:async';
import 'dart:math';

import 'package:flow_music/features/autoplay/data/autoplay_resolver.dart';
import 'package:flow_music/features/autoplay/data/mix_playlist_repository.dart';
import 'package:flow_music/features/autoplay/data/related_tracks_repository.dart';
import 'package:flow_music/features/autoplay/data/resolved_audio.dart';
import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/features/search/data/repositories/song_title_normalizer.dart';
import 'package:flow_music/features/search/data/repositories/youtube_suggestions_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'autoplay_queue_controller.g.dart';

/// Cuantas pistas proximas se resuelven (URL de audio lista) por adelantado.
/// Resolver es barato y es lo que hace que "next" arranque al instante aunque
/// la descarga a disco todavia no haya terminado.
///
/// La ventana es corta a proposito: cada resolucion pega a youtube.com y con
/// una cola larga YouTube llegaba a marcar la IP por exceso de peticiones
/// (ver `youtube_access_state.dart`), lo que tumbaba las descargas del usuario.
/// Cuatro por delante ya cubren el "next" instantaneo.
const int _resolveWindow = 4;

/// Las resoluciones van con cupo limitado y en orden de cola: la pista que
/// sigue termina antes que las de mas atras en vez de competir con ellas por el
/// ancho de banda (y sin disparar el limite de YouTube).
const int _maxConcurrentResolves = 2;

/// Empezamos a buscar mas musica bastante antes de que la cola visible se
/// vacie, para que el prefetch nunca se quede sin material.
const int _queueRefillThreshold = 8;
const int _queueTargetLength = 20;
const int _maxRefillBatches = 3;
const int _maxPlayedHistory = 40;

/// Cuanto crece la cola visible cada vez que el usuario sigue bajando por la
/// lista, y hasta donde. Ver mas pistas no cuesta ancho de banda: el prefetch
/// sigue mirando solo la cabeza de la cola.
const int _queueLoadMoreStep = 20;
const int _maxQueueLength = 120;

typedef AutoplaySuggestionLoader =
    Future<List<YouTubeSearchSuggestion>> Function(String query);
typedef AutoplayRelatedLoader =
    Future<List<YouTubeSearchSuggestion>> Function(
      YouTubeSearchSuggestion seed,
    );
typedef AutoplayMixLoader =
    Future<MixPlaylistPage> Function(YouTubeSearchSuggestion seed);
typedef AutoplayMixPageLoader =
    Future<MixPlaylistPage> Function(String playlistId, String nextPageToken);
typedef AutoplayAudioResolver =
    Future<ResolvedAudio?> Function(YouTubeSearchSuggestion suggestion);

/// Kept behind providers so queue behaviour can be tested without making
/// real YouTube/Piped requests.
final autoplaySuggestionLoaderProvider = Provider<AutoplaySuggestionLoader>((
  ref,
) {
  return (query) =>
      fetchYouTubeSearchSuggestions(query, source: 'AutoplayQueue');
});

final autoplayRelatedLoaderProvider = Provider<AutoplayRelatedLoader>((ref) {
  return fetchRelatedTracks;
});

final autoplayMixLoaderProvider = Provider<AutoplayMixLoader>((ref) {
  return fetchMixPlaylist;
});

final autoplayMixPageLoaderProvider = Provider<AutoplayMixPageLoader>((ref) {
  return (playlistId, nextPageToken) => fetchMixPlaylistPage(
    playlistId: playlistId,
    nextPageToken: nextPageToken,
  );
});

final autoplayAudioResolverProvider = Provider<AutoplayAudioResolver>((ref) {
  return resolveAudioFor;
});

class AutoplayQueueState {
  const AutoplayQueueState({
    required this.played,
    required this.current,
    required this.upcoming,
    required this.resolved,
    required this.inFlight,
    required this.isLoadingMore,
  });

  /// Tracks already played in this session, most-recent last.
  final List<YouTubeSearchSuggestion> played;

  /// The track that is currently playing (or about to play).
  final YouTubeSearchSuggestion? current;

  /// Tracks still waiting to play, in order.
  final List<YouTubeSearchSuggestion> upcoming;

  /// Resolved audio info keyed by videoId. Populated as prefetches succeed
  /// and consulted both for auto-advance and for manual next/prev navigation.
  final Map<String, ResolvedAudio> resolved;

  /// VideoIds currently being resolved.
  final Set<String> inFlight;

  /// Whether related songs are currently being appended to [upcoming].
  final bool isLoadingMore;

  static const AutoplayQueueState empty = AutoplayQueueState(
    played: [],
    current: null,
    upcoming: [],
    resolved: {},
    inFlight: {},
    isLoadingMore: false,
  );

  /// An active autoplay session can always request another track. If the
  /// buffer happens to be empty, [AutoplayQueueController.playNext] waits for
  /// an urgent refill instead of leaving the button disabled.
  bool get hasNext => current != null;
  bool get hasPrevious => played.isNotEmpty;

  /// Posicion de la pista actual dentro de la sesion (1 based) y total de
  /// pistas conocidas, para que la cola pueda decir "vas en la 5 de 24".
  int get currentPosition => current == null ? 0 : played.length + 1;
  int get totalTracks =>
      played.length + (current == null ? 0 : 1) + upcoming.length;

  /// Quedan pistas por pedir: la cola puede seguir creciendo hacia abajo.
  bool get canLoadMore => current != null && upcoming.length < _maxQueueLength;

  AutoplayQueueState copyWith({
    List<YouTubeSearchSuggestion>? played,
    Object? current = _noChange,
    List<YouTubeSearchSuggestion>? upcoming,
    Map<String, ResolvedAudio>? resolved,
    Set<String>? inFlight,
    bool? isLoadingMore,
  }) {
    return AutoplayQueueState(
      played: played ?? this.played,
      current: identical(current, _noChange)
          ? this.current
          : current as YouTubeSearchSuggestion?,
      upcoming: upcoming ?? this.upcoming,
      resolved: resolved ?? this.resolved,
      inFlight: inFlight ?? this.inFlight,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

const Object _noChange = Object();

class NextTrack {
  const NextTrack({required this.suggestion, this.resolved});

  final YouTubeSearchSuggestion suggestion;
  final ResolvedAudio? resolved;
}

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
@Riverpod(keepAlive: true)
class AutoplayQueueController extends _$AutoplayQueueController {
  int _queueGeneration = 0;
  int _refillFailures = 0;

  /// Techo vigente de la cola visible. Sube por pasos cuando el usuario pide
  /// ver mas (scroll hasta el final de la lista).
  int _queueTarget = _queueTargetLength;
  Future<void>? _refillFuture;
  Timer? _refillRetryTimer;

  /// Cancion que abrio la sesion: define la "linea" que deben seguir los
  /// rellenos, por mas que la cola avance.
  YouTubeSearchSuggestion? _anchor;

  final Set<String> _usedRefillQueries = {};

  /// VideoIds ya usados como semilla de "relacionados", para que cada relleno
  /// traiga material nuevo en vez de repetir el mismo pozo.
  final Set<String> _usedRelatedSeeds = {};

  /// Igual, pero para el mix (radio) de YouTube.
  final Set<String> _usedMixSeeds = {};

  /// Mix vigente: mientras haya token de continuacion, los rellenos siguen
  /// bajando por la misma radio en vez de abrir otra fuente.
  String? _mixPlaylistId;
  String? _mixNextPageToken;

  /// Todo lo que ya entro a la cola en esta sesion (aunque ya haya salido del
  /// historial acotado), para no volver a encolar la misma cancion.
  final Set<String> _sessionVideoIds = {};
  final Set<String> _sessionTrackKeys = {};

  /// Pistas cuya resolucion fallo. Sin esto el prefetch las reintentaria en
  /// bucle cerrado. Se limpia al avanzar de cancion, asi un fallo pasajero de
  /// red tiene otra oportunidad mas adelante.
  final Set<String> _resolveFailed = {};

  @override
  AutoplayQueueState build() {
    ref.onDispose(() => _refillRetryTimer?.cancel());
    return AutoplayQueueState.empty;
  }

  /// Replace the queue with [results], centring on [selectedIndex] as the
  /// currently-playing track and start prefetching its successors.
  void enqueue(List<YouTubeSearchSuggestion> results, int selectedIndex) {
    if (selectedIndex < 0 || selectedIndex >= results.length) {
      clear();
      return;
    }
    final selectedId = results[selectedIndex].videoId;
    if (selectedId.isEmpty) {
      clear();
      return;
    }

    _beginNewQueue();

    // La lista de resultados suele traer la misma cancion varias veces
    // (oficial, lyrics, audio...). Nos quedamos con la primera de cada una,
    // salvo la que el usuario toco, que entra siempre.
    final filtered = <YouTubeSearchSuggestion>[];
    for (final item in results) {
      if (item.videoId.isEmpty) continue;
      if (!_sessionVideoIds.add(item.videoId)) continue;
      final key = _dedupKey(item);
      final isSelected = item.videoId == selectedId;
      if (!isSelected && key.isNotEmpty && _sessionTrackKeys.contains(key)) {
        continue;
      }
      if (key.isNotEmpty) _sessionTrackKeys.add(key);
      filtered.add(item);
    }

    final newIndex = filtered.indexWhere((item) => item.videoId == selectedId);
    if (newIndex == -1) {
      clear();
      return;
    }

    _anchor = filtered[newIndex];

    state = AutoplayQueueState(
      played: filtered.sublist(0, newIndex),
      current: filtered[newIndex],
      upcoming: filtered.sublist(newIndex + 1),
      resolved: const {},
      inFlight: const {},
      isLoadingMore: false,
    );

    _pumpPrefetch();
    unawaited(_startQueueSources(_queueGeneration));
  }

  /// Advance to the next track. Returns the new current (with prefetched
  /// audio if ready). When the visible queue is momentarily empty, waits for
  /// the in-progress background refill before giving up.
  Future<NextTrack?> playNext() async {
    if (!await ensureNext()) return null;

    final current = state;
    if (current.upcoming.isEmpty) return null;

    final next = current.upcoming.first;
    final remaining = current.upcoming.sublist(1);
    final completeHistory = [
      ...current.played,
      if (current.current != null) current.current!,
    ];
    final played = _boundedHistory(completeHistory);
    final resolvedAudio = current.resolved[next.videoId];

    state = current.copyWith(
      played: played,
      current: next,
      upcoming: remaining,
    );
    _pruneResolvedEntries();
    _resolveFailed.clear();
    _pumpPrefetch();
    unawaited(_maintainQueueBuffer());
    return NextTrack(suggestion: next, resolved: resolvedAudio);
  }

  /// La siguiente pista ya resuelta, sin avanzar la cola.
  ///
  /// El reproductor la encola en su playlist nativa antes de que termine la
  /// actual, para que el paso de cancion no dependa de Dart en segundo plano.
  /// Si aun no estaba resuelta (o su URL caduco), la resuelve ahora.
  Future<NextTrack?> peekNextResolved() async {
    if (!await ensureNext()) return null;
    final head = state.upcoming.firstOrNull;
    if (head == null || head.videoId.isEmpty) return null;

    final known = state.resolved[head.videoId];
    if (known != null && !known.isUrlExpired) {
      return NextTrack(suggestion: head, resolved: known);
    }

    final resolved = await ref.read(autoplayAudioResolverProvider)(head);
    if (!ref.mounted || resolved == null) return null;
    if (state.upcoming.firstOrNull?.videoId != head.videoId) return null;
    state = state.copyWith(
      resolved: {...state.resolved, head.videoId: resolved},
    );
    return NextTrack(suggestion: head, resolved: resolved);
  }

  /// Ensure there is a concrete next song. This is public so playback entry
  /// points can await an urgent network refill when necessary.
  Future<bool> ensureNext() async {
    if (state.current == null) return false;
    if (state.upcoming.isNotEmpty) {
      unawaited(_maintainQueueBuffer());
      return true;
    }

    await _maintainQueueBuffer(force: true);
    return state.upcoming.isNotEmpty;
  }

  /// Alarga la cola visible mas alla del techo normal, para que el usuario
  /// pueda seguir bajando por la lista y ver que viene.
  ///
  /// Solo agrega pistas a la lista: las ventanas de prefetch y descarga siguen
  /// mirando la cabeza de la cola, asi que ver mas opciones no cuesta datos ni
  /// espacio en disco.
  Future<void> loadMoreUpcoming() {
    if (!state.canLoadMore) return Future.value();

    _queueTarget = min(
      _maxQueueLength,
      max(_queueTarget, state.upcoming.length + _queueLoadMoreStep),
    );
    return _maintainQueueBuffer(force: true);
  }

  NextTrack? playUpcomingAt(int index) {
    final current = state;
    if (index < 0 || index >= current.upcoming.length) return null;

    final next = current.upcoming[index];
    final before = current.upcoming.sublist(0, index);
    final after = current.upcoming.sublist(index + 1);
    final played = _boundedHistory([
      ...current.played,
      if (current.current != null) current.current!,
      ...before,
    ]);
    final resolvedAudio = current.resolved[next.videoId];

    state = current.copyWith(played: played, current: next, upcoming: after);
    _pruneResolvedEntries();
    _resolveFailed.clear();
    _pumpPrefetch();
    unawaited(_maintainQueueBuffer());
    return NextTrack(suggestion: next, resolved: resolvedAudio);
  }

  /// Go back to the previously-played track. Returns null when there is no
  /// history.
  NextTrack? playPrevious() {
    final current = state;
    if (current.played.isEmpty) return null;

    final previous = current.played.last;
    final played = current.played.sublist(0, current.played.length - 1);
    final upcoming = [
      if (current.current != null) current.current!,
      ...current.upcoming,
    ];
    final resolvedAudio = current.resolved[previous.videoId];

    state = current.copyWith(
      played: played,
      current: previous,
      upcoming: upcoming,
    );
    _pruneResolvedEntries();
    _resolveFailed.clear();
    _pumpPrefetch();
    unawaited(_maintainQueueBuffer());
    return NextTrack(suggestion: previous, resolved: resolvedAudio);
  }

  /// Salta a una pista concreta del historial (tocar una fila de "anteriores"
  /// en la cola). Lo que sonaba y lo que quedaba en medio vuelve al frente de
  /// la cola, en orden, asi que no se pierde nada de la sesion.
  NextTrack? playPlayedAt(int index) {
    final snapshot = state;
    if (index < 0 || index >= snapshot.played.length) return null;

    final target = snapshot.played[index];
    final played = snapshot.played.sublist(0, index);
    final upcoming = [
      ...snapshot.played.sublist(index + 1),
      if (snapshot.current != null) snapshot.current!,
      ...snapshot.upcoming,
    ];
    final resolvedAudio = snapshot.resolved[target.videoId];

    state = snapshot.copyWith(
      played: played,
      current: target,
      upcoming: upcoming,
    );
    _pruneResolvedEntries();
    _resolveFailed.clear();
    _pumpPrefetch();
    unawaited(_maintainQueueBuffer());
    return NextTrack(suggestion: target, resolved: resolvedAudio);
  }

  void clear() {
    _beginNewQueue();
    state = AutoplayQueueState.empty;
  }

  void clearUpcoming() {
    state = state.copyWith(upcoming: const []);
    _pruneResolvedEntries();
    unawaited(_maintainQueueBuffer(force: true));
  }

  void removeUpcomingAt(int index) {
    if (index < 0 || index >= state.upcoming.length) return;
    final next = [...state.upcoming]..removeAt(index);
    state = state.copyWith(upcoming: next);
    _pruneResolvedEntries();
    _pumpPrefetch();
    unawaited(_maintainQueueBuffer());
  }

  /// Baraja aleatoriamente las pistas que faltan por reproducir (Fisher-Yates),
  /// conservando la pista actual y el historial. Reinicia el prefetch del nuevo
  /// encabezado de la cola.
  void shuffleUpcoming() {
    final upcoming = [...state.upcoming];
    if (upcoming.length < 2) return;
    final random = Random();
    for (var i = upcoming.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final tmp = upcoming[i];
      upcoming[i] = upcoming[j];
      upcoming[j] = tmp;
    }
    state = state.copyWith(upcoming: upcoming);
    _pumpPrefetch();
    unawaited(_maintainQueueBuffer());
  }

  void moveUpcoming(int oldIndex, int newIndex) {
    final current = [...state.upcoming];
    if (oldIndex < 0 || oldIndex >= current.length) return;
    final target = newIndex;
    if (target < 0 || target > current.length) return;
    final item = current.removeAt(oldIndex);
    current.insert(target, item);
    state = state.copyWith(upcoming: current);
    _pumpPrefetch();
    unawaited(_maintainQueueBuffer());
  }

  void _beginNewQueue() {
    _queueGeneration++;
    _refillFailures = 0;
    _queueTarget = _queueTargetLength;
    _refillRetryTimer?.cancel();
    _refillRetryTimer = null;
    _refillFuture = null;
    _anchor = null;
    _usedRefillQueries.clear();
    _usedRelatedSeeds.clear();
    _usedMixSeeds.clear();
    _mixPlaylistId = null;
    _mixNextPageToken = null;
    _sessionVideoIds.clear();
    _sessionTrackKeys.clear();
    _resolveFailed.clear();
  }

  Future<void> _maintainQueueBuffer({bool force = false}) {
    if (!ref.mounted) return Future.value();
    if (state.current == null) return Future.value();
    if (!force && state.upcoming.length > _queueRefillThreshold) {
      return Future.value();
    }

    final activeRefill = _refillFuture;
    if (activeRefill != null) return activeRefill;

    _refillRetryTimer?.cancel();
    _refillRetryTimer = null;
    final generation = _queueGeneration;
    final refill = _refillQueue(generation);
    _refillFuture = refill;
    unawaited(
      refill.whenComplete(() {
        if (identical(_refillFuture, refill)) {
          _refillFuture = null;
        }
      }),
    );
    return refill;
  }

  Future<void> _refillQueue(int generation) async {
    if (!_isCurrentQueue(generation)) return;
    state = state.copyWith(isLoadingMore: true);

    var addedAny = false;
    try {
      for (
        var batch = 0;
        batch < _maxRefillBatches && state.upcoming.length < _queueTarget;
        batch++
      ) {
        if (!_isCurrentQueue(generation)) return;

        final additions = await _fetchMoreTracks(generation);
        if (!_isCurrentQueue(generation)) return;
        if (additions.isEmpty) continue;

        addedAny = true;
        state = state.copyWith(upcoming: [...state.upcoming, ...additions]);
        _pumpPrefetch();
      }
    } catch (error, stackTrace) {
      debugPrint('Autoplay queue refill failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (_isCurrentQueue(generation)) {
        state = state.copyWith(isLoadingMore: false);
        if (addedAny) {
          _refillFailures = 0;
        }
        if (state.upcoming.length <= _queueRefillThreshold) {
          _scheduleRefillRetry(generation);
        }
      }
    }
  }

  /// Arranca las fuentes de la cola al abrir una sesion: adelanta la radio de
  /// la cancion tocada y despues deja que el relleno normal complete lo que
  /// falte (o lo cubra todo, si el mix no respondio).
  Future<void> _startQueueSources(int generation) async {
    // Con lista detras hay que adelantar la radio a mano: el relleno normal no
    // se dispara hasta que la cola baja del umbral, y hasta entonces la
    // siguiente cancion saldria de los resultados de busqueda (covers,
    // recopilatorios, otros generos), que es lo que sonaba ajeno.
    if (state.upcoming.isNotEmpty) {
      await _primeMixRadio(generation);
      if (!_isCurrentQueue(generation)) return;
    }
    await _maintainQueueBuffer();
  }

  /// Adelanta la radio de la cancion tocada al frente de la cola, dejando
  /// detras la lista con la que se abrio la sesion.
  ///
  /// Ese respaldo es lo que hace que la reproduccion continua nunca se quede
  /// muda: si el mix no carga, la siguiente cancion sigue estando ahi.
  Future<void> _primeMixRadio(int generation) async {
    if (!_isCurrentQueue(generation)) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _loadMixPage(generation);
      if (page == null || !_isCurrentQueue(generation)) return;

      final fresh = _acceptFresh(page.tracks, ignoreRoom: true);
      if (fresh.isEmpty) return;

      state = state.copyWith(upcoming: [...fresh, ...state.upcoming]);
      _pumpPrefetch();
    } catch (error, stackTrace) {
      debugPrint('Autoplay mix priming failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (_isCurrentQueue(generation)) {
        state = state.copyWith(isLoadingMore: false);
      }
    }
  }

  /// Trae mas pistas de la misma linea musical, en orden de que tan bien
  /// conservan el genero:
  ///
  /// 1. el mix (radio) que YouTube arma alrededor de la cancion — ya viene
  ///    curado y se continua pagina por pagina con el mismo token;
  /// 2. los "relacionados" del video, que mezclan mas pero siguen cerca;
  /// 3. una busqueda por texto anclada, como ultimo recurso.
  Future<List<YouTubeSearchSuggestion>> _fetchMoreTracks(int generation) async {
    final fromMix = await _fetchFromMix(generation);
    if (!_isCurrentQueue(generation)) return const [];
    if (fromMix.isNotEmpty) return fromMix;

    final seed = _nextSeed(_usedRelatedSeeds);
    if (seed != null) {
      _usedRelatedSeeds.add(seed.videoId);
      final related = await ref.read(autoplayRelatedLoaderProvider)(seed);
      if (!_isCurrentQueue(generation)) return const [];
      final fresh = _acceptFresh(related);
      if (fresh.isNotEmpty) return fresh;
    }

    final query = _nextRefillQuery();
    if (query == null) return const [];
    final fetched = await ref.read(autoplaySuggestionLoaderProvider)(query);
    if (!_isCurrentQueue(generation)) return const [];
    return _acceptFresh(fetched);
  }

  /// Sigue bajando por el mix vigente y, si se agoto, abre el de otra semilla.
  /// Dos intentos por relleno: uno para la continuacion y otro para el mix
  /// nuevo, sin quedarse dando vueltas si ninguno trae material fresco.
  Future<List<YouTubeSearchSuggestion>> _fetchFromMix(int generation) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final page = await _loadMixPage(generation);
      if (page == null) return const [];
      if (!_isCurrentQueue(generation)) return const [];
      final fresh = _acceptFresh(page.tracks);
      if (fresh.isNotEmpty) return fresh;
    }
    return const [];
  }

  /// Siguiente pagina de mix, o null cuando ya no hay de donde pedir.
  Future<MixPlaylistPage?> _loadMixPage(int generation) async {
    final playlistId = _mixPlaylistId;
    final token = _mixNextPageToken;
    if (playlistId != null && (token ?? '').isNotEmpty) {
      final page = await ref.read(autoplayMixPageLoaderProvider)(
        playlistId,
        token!,
      );
      if (!_isCurrentQueue(generation)) return null;
      // Sin token nuevo el mix quedo agotado: el proximo intento abrira el de
      // otra semilla.
      _mixNextPageToken = page.nextPageToken;
      if (page.tracks.isNotEmpty) return page;
    }

    final seed = _nextSeed(_usedMixSeeds);
    if (seed == null) return null;
    _usedMixSeeds.add(seed.videoId);

    final page = await ref.read(autoplayMixLoaderProvider)(seed);
    if (!_isCurrentQueue(generation)) return null;
    if (page.isEmpty) return null;

    _mixPlaylistId = page.playlistId;
    _mixNextPageToken = page.nextPageToken;
    return page;
  }

  /// Semilla para pedir mix o relacionados: primero el ancla (la cancion que
  /// abrio la sesion), luego la que suena y despues la cabeza de la cola — que
  /// ya salio del mismo pozo, asi que la seleccion no se desvia de estilo.
  YouTubeSearchSuggestion? _nextSeed(Set<String> alreadyUsed) {
    final snapshot = state;
    final candidates = <YouTubeSearchSuggestion>[
      ?_anchor,
      if (snapshot.current != null) snapshot.current!,
      ...snapshot.upcoming,
      ...snapshot.played.reversed,
    ];
    for (final candidate in candidates) {
      if (candidate.videoId.isEmpty) continue;
      if (alreadyUsed.contains(candidate.videoId)) continue;
      return candidate;
    }
    return null;
  }

  /// Se queda solo con lo que no sono ni esta encolado en esta sesion, y sin
  /// pasarse del techo vigente de la cola.
  ///
  /// [ignoreRoom] deja pasar la pagina completa: lo usa el adelanto de la radio,
  /// que entra al frente de una cola que ya puede estar llena.
  List<YouTubeSearchSuggestion> _acceptFresh(
    List<YouTubeSearchSuggestion> candidates, {
    bool ignoreRoom = false,
  }) {
    final room = ignoreRoom
        ? candidates.length
        : _queueTarget - state.upcoming.length;
    if (room <= 0) return const [];

    final fresh = <YouTubeSearchSuggestion>[];
    for (final item in candidates) {
      if (fresh.length >= room) break;
      if (item.videoId.isEmpty) continue;
      if (!_sessionVideoIds.add(item.videoId)) continue;
      final key = _dedupKey(item);
      if (key.isNotEmpty && !_sessionTrackKeys.add(key)) continue;
      fresh.add(item);
    }
    return fresh;
  }

  String _dedupKey(YouTubeSearchSuggestion suggestion) {
    return songDedupKey(
      title: suggestion.displayText,
      artist: suggestion.channelTitle,
    );
  }

  String? _nextRefillQuery() {
    final candidates = <String>[
      ..._queryVariantsFor(_anchor ?? state.current),
      ..._queryVariantsFor(
        state.upcoming.isNotEmpty ? state.upcoming.last : state.current,
      ),
    ];
    for (final candidate in candidates) {
      final normalized = candidate.toLowerCase();
      if (_usedRefillQueries.add(normalized)) return candidate;
    }
    // All variants for the same anchor were already attempted. Allow them to
    // be retried after the exponential backoff: a previous failure may simply
    // have been a temporary network/provider outage.
    _usedRefillQueries.clear();
    if (candidates.isEmpty) return null;
    final candidate = candidates.first;
    _usedRefillQueries.add(candidate.toLowerCase());
    return candidate;
  }

  List<String> _queryVariantsFor(YouTubeSearchSuggestion? track) {
    if (track == null) return const [];
    final title = track.displayText.trim();
    final artist = track.channelTitle.trim();
    return <String>[
      if (title.isNotEmpty && artist.isNotEmpty) '$title $artist radio',
      if (title.isNotEmpty) '$title similar songs',
      if (artist.isNotEmpty) '$artist mix',
      if (artist.isNotEmpty) '$artist similar artists',
    ];
  }

  void _scheduleRefillRetry(int generation) {
    if (_refillRetryTimer != null || generation != _queueGeneration) return;
    final exponent = min(_refillFailures, 4);
    final delay = Duration(seconds: 2 << exponent);
    _refillFailures++;
    _refillRetryTimer = Timer(delay, () {
      _refillRetryTimer = null;
      if (!_isCurrentQueue(generation)) return;
      unawaited(_maintainQueueBuffer(force: true));
    });
  }

  bool _isCurrentQueue(int generation) {
    return ref.mounted &&
        generation == _queueGeneration &&
        state.current != null;
  }

  void _pruneResolvedEntries() {
    final relevantIds = <String>{
      ...state.played.map((item) => item.videoId),
      if (state.current != null) state.current!.videoId,
      ...state.upcoming.map((item) => item.videoId),
    };
    state = state.copyWith(
      resolved: Map.fromEntries(
        state.resolved.entries.where(
          (entry) => relevantIds.contains(entry.key),
        ),
      ),
    );
  }

  List<YouTubeSearchSuggestion> _boundedHistory(
    List<YouTubeSearchSuggestion> history,
  ) {
    if (history.length <= _maxPlayedHistory) return history;
    return history.sublist(history.length - _maxPlayedHistory);
  }

  /// Motor del prefetch en segundo plano. Se llama cada vez que la cola cambia
  /// (next, prev, reordenar, relleno) y cada vez que una tarea termina, asi que
  /// siempre hay pistas resolviendose por delante de la que suena.
  ///
  /// No descarga los archivos de audio: una cola que baja canciones completas
  /// en segundo plano compite con la pista elegida y consume datos moviles aun
  /// cuando el usuario nunca llega a escuchar esas canciones. La URL resuelta
  /// basta para que la siguiente pista empiece a transmitir rapidamente.
  void _pumpPrefetch() {
    _pumpResolves();
  }

  void _pumpResolves() {
    final targets = state.upcoming.take(_resolveWindow).toList(growable: false);
    for (final suggestion in targets) {
      if (state.inFlight.length >= _maxConcurrentResolves) return;
      final id = suggestion.videoId;
      if (id.isEmpty) continue;
      if (state.resolved.containsKey(id)) continue;
      if (state.inFlight.contains(id)) continue;
      if (_resolveFailed.contains(id)) continue;
      unawaited(_resolve(suggestion));
    }
  }

  Future<void> _resolve(YouTubeSearchSuggestion suggestion) async {
    final id = suggestion.videoId;
    state = state.copyWith(inFlight: {...state.inFlight, id});

    final resolved = await ref.read(autoplayAudioResolverProvider)(suggestion);
    if (!ref.mounted) return;

    final snapshot = state;
    final relevant = _isStillRelevant(snapshot, id);
    final inFlightAfterResolve = {...snapshot.inFlight}..remove(id);

    if (!relevant || resolved == null) {
      state = snapshot.copyWith(inFlight: inFlightAfterResolve);
      if (resolved == null) {
        _resolveFailed.add(id);
        debugPrint('Autoplay prefetch: no audio resolved for $id');
      }
      _pumpPrefetch();
      return;
    }

    state = snapshot.copyWith(
      resolved: {...snapshot.resolved, id: resolved},
      inFlight: inFlightAfterResolve,
    );
    debugPrint('Autoplay prefetch ready for $id');
    _pumpPrefetch();
  }

  bool _isStillRelevant(AutoplayQueueState snapshot, String videoId) {
    if (snapshot.upcoming.any((item) => item.videoId == videoId)) return true;
    if (snapshot.played.any((item) => item.videoId == videoId)) return true;
    return snapshot.current?.videoId == videoId;
  }
}
