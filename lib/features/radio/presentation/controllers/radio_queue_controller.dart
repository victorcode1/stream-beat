import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/data/station_removals_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Cola de emisoras de la sesion actual.
///
/// Cuando el usuario toca una emisora dentro de una lista (favoritos, lista de
/// radios, biblioteca o el explorador), encolamos toda la lista centrada en la
/// emisora tocada. Eso permite que el reproductor de radio y el mini player
/// avancen a la siguiente / anterior emisora, igual que la cola de autoplay
/// hace con las canciones.
class RadioQueueState {
  const RadioQueueState({required this.stations, required this.index});

  /// Emisoras reproducibles de la lista de origen, en orden.
  final List<RadioStation> stations;

  /// Indice de la emisora actual dentro de [stations]; `-1` si esta vacia.
  final int index;

  static const RadioQueueState empty = RadioQueueState(
    stations: <RadioStation>[],
    index: -1,
  );

  bool get hasNext => index >= 0 && index < stations.length - 1;
  bool get hasPrevious => index > 0;

  RadioStation? get current =>
      (index >= 0 && index < stations.length) ? stations[index] : null;
}

final radioQueueControllerProvider =
    NotifierProvider<RadioQueueController, RadioQueueState>(
      RadioQueueController.new,
    );

class RadioQueueController extends Notifier<RadioQueueState> {
  @override
  RadioQueueState build() => RadioQueueState.empty;

  /// Reemplaza la cola con [stations] centrada en [selectedIndex].
  void enqueue(List<RadioStation> stations, int selectedIndex) {
    if (selectedIndex < 0 || selectedIndex >= stations.length) {
      state = RadioQueueState.empty;
      return;
    }
    final selectedId = _idOf(stations[selectedIndex]);
    final playable = stations
        .where(
          (station) =>
              station.isPlayable &&
              !StationRemovalsRepository.instance.current.contains(station),
        )
        .toList(growable: false);
    final newIndex = playable.indexWhere(
      (station) => _idOf(station) == selectedId,
    );
    if (newIndex == -1) {
      state = RadioQueueState.empty;
      return;
    }
    state = RadioQueueState(stations: playable, index: newIndex);
  }

  /// Avanza a la siguiente emisora y la devuelve, o `null` si no hay.
  RadioStation? next() {
    if (!state.hasNext) return null;
    var nextIndex = state.index + 1;
    while (nextIndex < state.stations.length &&
        StationRemovalsRepository.instance.current.contains(
          state.stations[nextIndex],
        )) {
      nextIndex++;
    }
    if (nextIndex >= state.stations.length) return null;
    state = RadioQueueState(stations: state.stations, index: nextIndex);
    return state.stations[nextIndex];
  }

  /// Retrocede a la emisora anterior y la devuelve, o `null` si no hay.
  RadioStation? previous() {
    if (!state.hasPrevious) return null;
    var prevIndex = state.index - 1;
    while (prevIndex >= 0 &&
        StationRemovalsRepository.instance.current.contains(
          state.stations[prevIndex],
        )) {
      prevIndex--;
    }
    if (prevIndex < 0) return null;
    state = RadioQueueState(stations: state.stations, index: prevIndex);
    return state.stations[prevIndex];
  }

  /// Alinea el indice actual con la emisora identificada por [stationId] sin
  /// alterar la lista. Util cuando la reproduccion cambia desde otra pantalla.
  void syncToStationId(String stationId) {
    if (stationId.isEmpty) return;
    final found = state.stations.indexWhere(
      (station) => _idOf(station) == stationId,
    );
    if (found != -1 && found != state.index) {
      state = RadioQueueState(stations: state.stations, index: found);
    }
  }

  void clear() => state = RadioQueueState.empty;

  String _idOf(RadioStation station) =>
      station.stationUuid.isEmpty ? station.streamUrl : station.stationUuid;
}
