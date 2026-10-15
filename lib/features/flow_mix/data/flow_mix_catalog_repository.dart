import 'package:flow_music/features/flow_mix/domain/flow_mix_mood.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/data/repositories/radio_browser_repository.dart';
import 'package:flutter/foundation.dart';

typedef RadioBrowserRepositoryFactory = RadioBrowserRepository Function();

class FlowMixCatalogRepository {
  FlowMixCatalogRepository({RadioBrowserRepositoryFactory? repositoryFactory})
    : _repositoryFactory = repositoryFactory ?? RadioBrowserRepository.new;

  final RadioBrowserRepositoryFactory _repositoryFactory;

  Future<List<RadioStation>> loadCandidates({
    required FlowMixMood mood,
    required Iterable<RadioStation> favorites,
    required Set<String> preferredTags,
    String countryCode = '',
  }) async {
    final repository = _repositoryFactory();
    try {
      final normalizedCountry = countryCode.trim().toUpperCase();
      final tags = <String>{...mood.discoveryTags, ...preferredTags}.take(3);
      final requests = <Future<List<RadioStation>>>[
        _safeLoad('top stations', () => repository.topStations(limit: 80)),
        if (normalizedCountry.isNotEmpty)
          _safeLoad(
            'country stations',
            () => repository.searchStations(
              countryCode: normalizedCountry,
              limit: mood == FlowMixMood.local ? 80 : 40,
            ),
          ),
        for (final tag in tags)
          _safeLoad(
            'tag $tag',
            () => repository.searchStations(tag: tag, limit: 45),
          ),
      ];

      final batches = await Future.wait(requests);
      final unique = <String, RadioStation>{};
      for (final station in <RadioStation>[
        ...favorites,
        ...batches.expand((batch) => batch),
      ]) {
        final id = station.stationUuid.isEmpty
            ? station.streamUrl
            : station.stationUuid;
        if (id.isEmpty ||
            !station.isPlayable ||
            repository.removalsRepository.current.contains(station)) {
          continue;
        }
        unique[id] = station;
      }
      return repository.healthRepository.rank(unique.values);
    } finally {
      repository.close();
    }
  }

  Future<List<RadioStation>> _safeLoad(
    String source,
    Future<List<RadioStation>> Function() load,
  ) async {
    try {
      return await load();
    } catch (error) {
      debugPrint('Flow Mix could not load $source: $error');
      return const [];
    }
  }
}
