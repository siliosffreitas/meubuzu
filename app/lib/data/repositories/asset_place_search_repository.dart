import '../../domain/repositories/place_search_repository.dart';
import '../../domain/models/bus_stop.dart';
import '../../domain/models/line.dart';
import '../models/place_suggestion.dart';
import '../services/bus_stop_service.dart';
import '../services/line_search_service.dart';

/// Implementação da busca de linhas e paradas a partir dos serviços de catálogo.
class AssetPlaceSearchRepository implements PlaceSearchRepository {
  const AssetPlaceSearchRepository({
    required this._lineSearchService,
    required this._busStopService,
  });

  final LineSearchService _lineSearchService;
  final BusStopService _busStopService;

  @override
  Future<List<PlaceSuggestion>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    final lines = [
      ...await _lineSearchService.search(trimmed),
    ]..removeWhere((line) => line.publicCode.isEmpty)
      ..sort(_compareLines);
    final stops = await _busStopService.search(trimmed);

    return <PlaceSuggestion>[
      for (final line in lines) _lineToSuggestion(line),
      for (final stop in stops) _stopToSuggestion(stop),
    ];
  }

  PlaceSuggestion _lineToSuggestion(Line line) {
    return PlaceSuggestion(
      code: line.publicCode,
      type: PlaceSuggestionType.line,
      title: line.name,
      subtitle: _lineRoute(line),
      latitude: line.latitude,
      longitude: line.longitude,
    );
  }

  int _compareLines(Line first, Line second) {
    final codeComparison = first.publicCode
        .toLowerCase()
        .compareTo(second.publicCode.toLowerCase());
    if (codeComparison != 0) {
      return codeComparison;
    }
    return first.name.toLowerCase().compareTo(second.name.toLowerCase());
  }

  PlaceSuggestion _stopToSuggestion(BusStop stop) {
    return PlaceSuggestion(
      code: stop.code,
      type: PlaceSuggestionType.stop,
      title: stop.name,
      subtitle: stop.address,
      latitude: stop.latitude,
      longitude: stop.longitude,
    );
  }

  /// Monta o texto secundário da linha a partir da origem e do destino.
  String _lineRoute(Line line) {
    final origin = line.origin.trim();
    final destination = line.destination.trim();
    if (origin.isEmpty) {
      return destination;
    }
    if (destination.isEmpty) {
      return origin;
    }
    if (origin == destination) {
      return 'Circular • $origin';
    }
    return '$origin → $destination';
  }

  @override
  void dispose() {}
}
