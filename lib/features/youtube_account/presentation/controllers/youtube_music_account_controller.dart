import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/features/search/data/repositories/youtube_suggestions_repository.dart';
import 'package:flow_music/features/settings/presentation/controllers/theme_mode_controller.dart';
import 'package:flow_music/features/youtube_account/data/youtube_library_store.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_account_repository.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_cookie.dart';
import 'package:flow_music/features/youtube_account/data/youtube_music_library_parser.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final youtubeMusicAccountControllerProvider =
    NotifierProvider<YouTubeMusicAccountController, YouTubeMusicCookie?>(
      YouTubeMusicAccountController.new,
    );

/// Repositorio de la sesion actual; null mientras no haya cuenta conectada.
final youtubeMusicAccountRepositoryProvider =
    Provider<YouTubeMusicAccountRepository?>((ref) {
      final cookie = ref.watch(youtubeMusicAccountControllerProvider);
      return cookie == null ? null : YouTubeMusicAccountRepository(cookie);
    });

/// Encabezados de la sesion para las busquedas; null sin cuenta.
final youtubeSessionHeadersProvider = Provider<YouTubeSessionHeaders?>((ref) {
  final cookie = ref.watch(youtubeMusicAccountControllerProvider);
  if (cookie == null) return null;
  return (origin) => cookie.sessionHeaders(origin, DateTime.now());
});

/// Nombre y foto de la cuenta conectada; null sin cuenta.
final youtubeMusicAccountInfoProvider =
    FutureProvider<YouTubeMusicAccountInfo?>((ref) async {
      final repository = ref.watch(youtubeMusicAccountRepositoryProvider);
      return repository?.fetchAccount();
    });

/// Apartado «YouTube» de la Biblioteca: las listas de la cuenta guardadas en
/// el dispositivo en la ultima sincronizacion.
final youtubeLibraryProvider =
    NotifierProvider<YouTubeLibraryController, List<SavedYouTubePlaylist>>(
      YouTubeLibraryController.new,
    );

class YouTubeLibraryController extends Notifier<List<SavedYouTubePlaylist>> {
  static const _store = YouTubeLibraryStore();

  @override
  List<SavedYouTubePlaylist> build() => _store.readAll();

  Future<void> replaceAll(List<SavedYouTubePlaylist> playlists) async {
    await _store.replaceAll(playlists);
    state = List.unmodifiable(playlists);
  }

  Future<void> clear() async {
    await _store.clear();
    ref.invalidate(youtubeLastSyncProvider);
    state = const [];
  }
}

/// Hora de la ultima sincronizacion correcta, para «Ultima vez: ...».
final youtubeLastSyncProvider =
    NotifierProvider<YouTubeLastSyncController, DateTime?>(
      YouTubeLastSyncController.new,
    );

class YouTubeLastSyncController extends Notifier<DateTime?> {
  static const _store = YouTubeLibraryStore();

  @override
  DateTime? build() => _store.readSyncedAt();

  Future<void> markSynced(DateTime time) async {
    await _store.writeSyncedAt(time);
    state = time;
  }
}

/// Numero de artistas a los que la cuenta esta suscrita; null sin cuenta.
final youtubeSubscribedArtistsCountProvider = FutureProvider<int?>((ref) async {
  final repository = ref.watch(youtubeMusicAccountRepositoryProvider);
  if (repository == null) return null;
  return (await repository.fetchSubscribedArtists()).length;
});

final youtubeMusicPlaylistTracksProvider =
    FutureProvider.family<List<YouTubeSearchSuggestion>, String>((
      ref,
      playlistId,
    ) async {
      final repository = ref.watch(youtubeMusicAccountRepositoryProvider);
      if (repository == null) return const [];
      return repository.fetchPlaylistTracks(playlistId);
    });

/// Cuenta de YouTube Music conectada con la cookie del navegador.
///
/// La cookie se guarda en la caja de ajustes del dispositivo, sin cifrar: es
/// una prueba interna y no debe llegar a la version de las tiendas.
class YouTubeMusicAccountController extends Notifier<YouTubeMusicCookie?> {
  static const _cookieKey = 'youtube_music_cookie';

  Box get _box => Hive.box(settingsBoxName);

  @override
  YouTubeMusicCookie? build() {
    final raw = _box.get(_cookieKey);
    return raw is String ? YouTubeMusicCookie.tryParse(raw) : null;
  }

  /// Comprueba la cookie contra YouTube antes de guardarla. Devuelve false si
  /// no trae la cookie de sesion; lanza si YouTube la rechaza.
  Future<bool> connect(String raw) async {
    final cookie = YouTubeMusicCookie.tryParse(raw);
    if (cookie == null) return false;
    await YouTubeMusicAccountRepository(cookie).fetchPlaylists();
    await _box.put(_cookieKey, cookie.header);
    state = cookie;
    return true;
  }

  /// Cierra la sesion y borra la copia local de la cuenta: otra cuenta no
  /// debe ver las listas de esta.
  Future<void> disconnect() async {
    await _box.delete(_cookieKey);
    await ref.read(youtubeLibraryProvider.notifier).clear();
    state = null;
  }
}

/// Filas del Inicio de la cuenta; vacio sin cuenta. Si falla (sesion vencida,
/// sin red) el Inicio sigue con sus secciones propias.
final youtubeMusicHomeProvider = FutureProvider<List<YouTubeMusicHomeShelf>>((
  ref,
) async {
  final repository = ref.watch(youtubeMusicAccountRepositoryProvider);
  if (repository == null) return const [];
  return repository.fetchHome();
});
