import 'package:flow_music/features/search/data/models/youtube_search_suggestion.dart';
import 'package:flow_music/features/search/data/repositories/youtube_music_search_parser.dart';

/// Lista de reproduccion de la biblioteca de YouTube Music del usuario.
class YouTubeMusicPlaylist {
  const YouTubeMusicPlaylist({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.thumbnailUrl,
  });

  /// Id de la lista sin el prefijo `VL` (por ejemplo `LM` para «Me gusta»).
  final String id;
  final String title;
  final String subtitle;
  final String thumbnailUrl;
}

/// Datos de la cuenta conectada para el avatar de la barra superior.
class YouTubeMusicAccountInfo {
  const YouTubeMusicAccountInfo({
    required this.name,
    required this.handle,
    required this.photoUrl,
    this.email = '',
    this.hasPremium,
  });

  final String name;

  /// `@usuario` del canal; puede venir vacio.
  final String handle;
  final String photoUrl;

  /// Correo de la cuenta; vacio si YouTube no lo envia.
  final String email;

  /// YouTube Premium segun `has_unlimited_entitlement`; null si no viene.
  final bool? hasPremium;
}

/// Tarjeta del Inicio: una cancion para reproducir o una lista para abrir.
class YouTubeMusicHomeItem {
  const YouTubeMusicHomeItem.song(YouTubeSearchSuggestion this.song)
    : playlist = null;

  const YouTubeMusicHomeItem.playlist(YouTubeMusicPlaylist this.playlist)
    : song = null;

  final YouTubeSearchSuggestion? song;
  final YouTubeMusicPlaylist? playlist;

  String get title => song?.displayText ?? playlist!.title;
  String get subtitle => song?.channelTitle ?? playlist!.subtitle;
  String get thumbnailUrl => song?.thumbnailUrl ?? playlist!.thumbnailUrl;
}

/// Fila del Inicio de YouTube Music («Volver a escuchar», «Mixes para ti»...).
class YouTubeMusicHomeShelf {
  const YouTubeMusicHomeShelf({required this.title, required this.items});

  final String title;
  final List<YouTubeMusicHomeItem> items;

  /// Las canciones de la fila, para reproducirlas como una lista.
  List<YouTubeSearchSuggestion> get songs => [
    for (final item in items) ?item.song,
  ];
}

/// Una pagina de resultados y el token para pedir la siguiente.
class YouTubeMusicPage<T> {
  const YouTubeMusicPage(this.items, this.continuation);

  final List<T> items;
  final String? continuation;
}

/// Lee las respuestas de `youtubei/v1/browse` de una sesion iniciada.
///
/// Solo mira dentro de los contenedores de la lista pedida: la misma respuesta
/// trae otras secciones (sugerencias, listas relacionadas) con sus propios
/// tokens de continuacion, que no son parte de la lista.
class YouTubeMusicLibraryParser {
  const YouTubeMusicLibraryParser();

  static const _trackParser = YouTubeMusicSearchParser();

  static const _playlistRoots = {
    'gridRenderer',
    'gridContinuation',
    'appendContinuationItemsAction',
  };

  static const _trackRoots = {
    'musicPlaylistShelfRenderer',
    'musicPlaylistShelfContinuation',
    'appendContinuationItemsAction',
  };

  static const _artistRoots = {
    'musicShelfRenderer',
    'musicShelfContinuation',
    'appendContinuationItemsAction',
  };

  static const _homeRoots = {'sectionListRenderer', 'sectionListContinuation'};

  YouTubeMusicPage<YouTubeMusicPlaylist> parsePlaylists(Object? data) {
    final roots = _findRoots(data, _playlistRoots).toList();
    final playlists = <YouTubeMusicPlaylist>[];
    final seenIds = <String>{};
    for (final item in _collect(roots, 'musicTwoRowItemRenderer')) {
      final playlist = _parsePlaylist(item);
      if (playlist != null && seenIds.add(playlist.id)) {
        playlists.add(playlist);
      }
    }
    return YouTubeMusicPage(
      List.unmodifiable(playlists),
      _findContinuation(roots),
    );
  }

  YouTubeMusicPage<YouTubeSearchSuggestion> parseTracks(Object? data) {
    final roots = _findRoots(data, _trackRoots).toList();
    return YouTubeMusicPage(
      _trackParser.parseSuggestions(roots, limit: 1 << 20),
      _findContinuation(roots),
    );
  }

  /// Filas del Inicio. El token sale solo de la lista de secciones: las filas
  /// no se paginan aqui.
  YouTubeMusicPage<YouTubeMusicHomeShelf> parseHome(Object? data) {
    final roots = _findRoots(data, _homeRoots).toList();
    final shelves = <YouTubeMusicHomeShelf>[];
    for (final shelf in _collect(roots, 'musicCarouselShelfRenderer')) {
      final parsed = _parseShelf(shelf);
      if (parsed != null) shelves.add(parsed);
    }
    String? continuation;
    for (final root in roots) {
      continuation ??= _findContinuation(root['continuations']);
    }
    return YouTubeMusicPage(List.unmodifiable(shelves), continuation);
  }

  /// Nombre y foto de `account/account_menu`; null si no viene la cabecera
  /// de la cuenta activa.
  YouTubeMusicAccountInfo? parseAccount(Object? data) {
    final header = _collect(data, 'activeAccountHeaderRenderer').firstOrNull;
    if (header == null) return null;
    final name = _joinRuns(_runs(header['accountName']));
    if (name.isEmpty) return null;
    final email = header['email'];
    return YouTubeMusicAccountInfo(
      name: name,
      handle: _joinRuns(_runs(header['channelHandle'])),
      photoUrl: _lastThumbnail({
        'musicThumbnailRenderer': {'thumbnail': header['accountPhoto']},
      }),
      email: email is String ? email.trim() : _joinRuns(_runs(email)),
      hasPremium: switch (_trackingParam(data, 'has_unlimited_entitlement')) {
        'True' => true,
        'False' => false,
        _ => null,
      },
    );
  }

  /// Artistas a los que la cuenta esta suscrita
  /// (`FEmusic_library_corpus_artists`), por su id de canal.
  YouTubeMusicPage<String> parseSubscribedArtists(Object? data) {
    final roots = _findRoots(data, _artistRoots).toList();
    final ids = <String>{};
    for (final item in _collect(roots, 'musicResponsiveListItemRenderer')) {
      final id = _browseId(item['navigationEndpoint']);
      if (id != null && id.startsWith('UC')) ids.add(id);
    }
    return YouTubeMusicPage(List.unmodifiable(ids), _findContinuation(roots));
  }

  /// Valor de `responseContext.serviceTrackingParams` con la clave [key].
  String? _trackingParam(Object? data, String key) {
    final context = data is Map ? data['responseContext'] : null;
    final services = context is Map ? context['serviceTrackingParams'] : null;
    if (services is! List) return null;
    for (final service in services) {
      final params = service is Map ? service['params'] : null;
      if (params is! List) continue;
      for (final param in params) {
        if (param is Map && param['key'] == key && param['value'] is String) {
          return param['value'] as String;
        }
      }
    }
    return null;
  }

  /// Pagina de la radio de una cancion (`youtubei/v1/next`). En las
  /// continuaciones la respuesta repite la cola original en `contents`; solo
  /// cuenta lo nuevo, en `continuationContents`.
  YouTubeMusicPage<YouTubeSearchSuggestion> parseRadio(Object? data) {
    final continued = data is Map ? data['continuationContents'] : null;
    final root = continued ?? data;
    String? token;
    for (final next in _collect(root, 'nextRadioContinuationData')) {
      final value = next['continuation'];
      if (value is String && value.isNotEmpty) token = value;
    }
    return YouTubeMusicPage(parseMixTracks(root), token);
  }

  /// Cola de un mix (`RD...`) devuelta por `youtubei/v1/next`.
  List<YouTubeSearchSuggestion> parseMixTracks(Object? data) {
    final songs = <YouTubeSearchSuggestion>[];
    final seenIds = <String>{};
    for (final item in _collect(data, 'playlistPanelVideoRenderer')) {
      final videoId = item['videoId'];
      final title = _joinRuns(_runs(item['title']));
      if (videoId is! String || title.isEmpty || !seenIds.add(videoId)) {
        continue;
      }
      songs.add(
        YouTubeSearchSuggestion(
          videoId: videoId,
          displayText: title,
          channelTitle: _firstByline(_runs(item['longBylineText'])),
          thumbnailUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
          duration: _parseDuration(_joinRuns(_runs(item['lengthText']))),
        ),
      );
    }
    return List.unmodifiable(songs);
  }

  YouTubeMusicHomeShelf? _parseShelf(Map<Object?, Object?> shelf) {
    final header = shelf['header'];
    final basic = header is Map
        ? header['musicCarouselShelfBasicHeaderRenderer']
        : null;
    final title = _joinRuns(_runs(basic is Map ? basic['title'] : null));
    final contents = shelf['contents'];
    if (title.isEmpty || contents is! List) return null;

    final items = <YouTubeMusicHomeItem>[];
    for (final entry in contents.whereType<Map<Object?, Object?>>()) {
      final card = entry['musicTwoRowItemRenderer'];
      final row = entry['musicResponsiveListItemRenderer'];
      final item = card is Map<Object?, Object?>
          ? _parseCard(card)
          : row is Map<Object?, Object?>
          ? _parseRow(row)
          : null;
      if (item != null) items.add(item);
    }
    if (items.isEmpty) return null;
    return YouTubeMusicHomeShelf(title: title, items: List.unmodifiable(items));
  }

  YouTubeMusicHomeItem? _parseRow(Map<Object?, Object?> row) {
    final songs = _trackParser.parseSuggestions({
      'musicResponsiveListItemRenderer': row,
    });
    if (songs.isEmpty) return null;
    // El artista viene con «• 77 M reproducciones» detras.
    final song = songs.first;
    return YouTubeMusicHomeItem.song(
      YouTubeSearchSuggestion(
        videoId: song.videoId,
        displayText: song.displayText,
        channelTitle: song.channelTitle.split(' • ').first,
        thumbnailUrl: song.thumbnailUrl,
        duration: song.duration,
      ),
    );
  }

  /// Una tarjeta abre una lista (por su `browseId` o por el boton de
  /// reproducir de albumes y mixes) o es una cancion suelta. Los artistas y
  /// la tarjeta «Nueva lista» no traen ninguna de las dos y se omiten.
  YouTubeMusicHomeItem? _parseCard(Map<Object?, Object?> item) {
    final titleRuns = _runs(item['title']);
    final title = _joinRuns(titleRuns);
    if (title.isEmpty) return null;
    final subtitle = _joinRuns(_runs(item['subtitle']));
    final thumbnailUrl = _lastThumbnail(item['thumbnailRenderer']);

    final navigation = item['navigationEndpoint'];
    final watch = navigation is Map ? navigation['watchEndpoint'] : null;
    final videoId = watch is Map ? watch['videoId'] : null;
    if (videoId is String && videoId.isNotEmpty) {
      return YouTubeMusicHomeItem.song(
        YouTubeSearchSuggestion(
          videoId: videoId,
          displayText: title,
          channelTitle: subtitle.split(' • ').first,
          thumbnailUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
        ),
      );
    }

    final browseId =
        _browseId(navigation) ??
        _browseId(titleRuns.firstOrNull?['navigationEndpoint']);
    final playlistId = browseId != null && browseId.startsWith('VL')
        ? browseId.substring(2)
        : _overlayPlaylistId(item['thumbnailOverlay']);
    if (playlistId == null) return null;
    return YouTubeMusicHomeItem.playlist(
      YouTubeMusicPlaylist(
        id: playlistId,
        title: title,
        subtitle: subtitle,
        thumbnailUrl: thumbnailUrl,
      ),
    );
  }

  YouTubeMusicPlaylist? _parsePlaylist(Map<Object?, Object?> item) {
    return _parseCard(item)?.playlist;
  }

  String? _overlayPlaylistId(Object? overlay) {
    final renderer = overlay is Map
        ? overlay['musicItemThumbnailOverlayRenderer']
        : null;
    final content = renderer is Map ? renderer['content'] : null;
    final button = content is Map ? content['musicPlayButtonRenderer'] : null;
    final play = button is Map ? button['playNavigationEndpoint'] : null;
    final watch = play is Map ? play['watchPlaylistEndpoint'] : null;
    final id = watch is Map ? watch['playlistId'] : null;
    return id is String && id.isNotEmpty ? id : null;
  }

  String _firstByline(List<Map<Object?, Object?>> runs) {
    return _joinRuns(runs).split(' • ').first;
  }

  Duration? _parseDuration(String text) {
    final parts = text.split(':').map(int.tryParse).toList();
    if (parts.length < 2 || parts.length > 3 || parts.contains(null)) {
      return null;
    }
    var seconds = 0;
    for (final part in parts) {
      seconds = seconds * 60 + part!;
    }
    return seconds > 0 ? Duration(seconds: seconds) : null;
  }

  Iterable<Map<Object?, Object?>> _findRoots(
    Object? node,
    Set<String> keys,
  ) sync* {
    if (node is List) {
      for (final entry in node) {
        yield* _findRoots(entry, keys);
      }
      return;
    }
    if (node is! Map) return;
    for (final entry in node.entries) {
      final value = entry.value;
      if (keys.contains(entry.key) && value is Map) {
        yield value;
      } else {
        yield* _findRoots(value, keys);
      }
    }
  }

  Iterable<Map<Object?, Object?>> _collect(Object? node, String key) sync* {
    if (node is List) {
      for (final entry in node) {
        yield* _collect(entry, key);
      }
      return;
    }
    if (node is! Map) return;
    final match = node[key];
    if (match is Map) {
      yield match;
      return;
    }
    for (final value in node.values) {
      yield* _collect(value, key);
    }
  }

  String? _findContinuation(Object? node) {
    if (node is List) {
      for (final entry in node) {
        final token = _findContinuation(entry);
        if (token != null) return token;
      }
      return null;
    }
    if (node is! Map) return null;

    final command = node['continuationCommand'];
    if (command is Map && command['token'] is String) {
      return command['token'] as String;
    }
    final next = node['nextContinuationData'];
    if (next is Map && next['continuation'] is String) {
      return next['continuation'] as String;
    }
    for (final value in node.values) {
      final token = _findContinuation(value);
      if (token != null) return token;
    }
    return null;
  }

  List<Map<Object?, Object?>> _runs(Object? text) {
    final runs = text is Map ? text['runs'] : null;
    if (runs is! List) return const [];
    return runs.whereType<Map<Object?, Object?>>().toList();
  }

  String _joinRuns(List<Map<Object?, Object?>> runs) {
    return runs
        .map((run) => run['text'])
        .whereType<String>()
        .join()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _browseId(Object? endpoint) {
    final browse = endpoint is Map ? endpoint['browseEndpoint'] : null;
    final id = browse is Map ? browse['browseId'] : null;
    return id is String && id.isNotEmpty ? id : null;
  }

  String _lastThumbnail(Object? renderer) {
    final music = renderer is Map ? renderer['musicThumbnailRenderer'] : null;
    final thumbnail = music is Map ? music['thumbnail'] : null;
    final thumbnails = thumbnail is Map ? thumbnail['thumbnails'] : null;
    if (thumbnails is! List || thumbnails.isEmpty) return '';
    final last = thumbnails.last;
    final url = last is Map ? last['url'] : null;
    return url is String ? url : '';
  }
}
