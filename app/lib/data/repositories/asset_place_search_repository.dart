import '../../domain/repositories/place_search_repository.dart';
import '../models/bus_stop.dart';
import '../models/line.dart';
import '../models/place_suggestion.dart';
import '../services/bus_stop_service.dart';
import '../services/line_search_service.dart';

/// Implementação baseada nos catálogos locais para busca de linhas e paradas.
class AssetPlaceSearchRepository implements PlaceSearchRepository {
  AssetPlaceSearchRepository({
    LineSearchService? lineSearchService,
    BusStopService? busStopService,
  }) : _lineSearchService = lineSearchService ?? AssetLineSearchService(),
       _busStopService = busStopService ?? AssetBusStopService();

  final LineSearchService _lineSearchService;
  final BusStopService _busStopService;

  @override
  Future<List<PlaceSuggestion>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    final lines = await _lineSearchService.search(trimmed);
    final stops = await _busStopService.search(trimmed);

    final suggestions = <PlaceSuggestion>[
      for (final line in lines) _lineToSuggestion(line),
      for (final stop in stops) _stopToSuggestion(stop),
    ];
    return suggestions;
  }

  PlaceSuggestion _lineToSuggestion(Line line) {
    return PlaceSuggestion(
      id: line.id,
      type: PlaceSuggestionType.line,
      title: line.id,
      subtitle: line.name,
      latitude: line.latitude,
      longitude: line.longitude,
    );
  }

  PlaceSuggestion _stopToSuggestion(BusStop stop) {
    return PlaceSuggestion(
      id: stop.code,
      type: PlaceSuggestionType.stop,
      title: stop.name,
      subtitle: stop.address,
      latitude: stop.latitude,
      longitude: stop.longitude,
    );
  }

  @override
  void dispose() {}
}
