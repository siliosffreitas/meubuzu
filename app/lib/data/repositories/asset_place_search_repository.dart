import '../../domain/repositories/place_search_repository.dart';
import '../../domain/models/bus_stop.dart';
import '../../domain/models/line.dart';
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

    final lines = [...await _lineSearchService.search(trimmed)]
      ..sort(_compareLines);
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
      code: _displayCode(line),
      type: PlaceSuggestionType.line,
      title: line.name,
      subtitle: _lineRoute(line),
      latitude: line.latitude,
      longitude: line.longitude,
    );
  }

  /// Código exibido da linha: o `sgLinha` quando existe, senão o `codigoLinha`.
  String _displayCode(Line line) {
    final code = line.boardingCode?.trim();
    return code == null || code.isEmpty ? line.id : code;
  }

  /// Ordena as linhas pelo `sgLinha` (fallback para o código interno).
  int _compareLines(Line first, Line second) {
    final codeComparison = _displayCode(first)
        .toLowerCase()
        .compareTo(_displayCode(second).toLowerCase());
    if (codeComparison != 0) {
      return codeComparison;
    }
    return first.name.toLowerCase().compareTo(second.name.toLowerCase());
  }

  PlaceSuggestion _stopToSuggestion(BusStop stop) {
    return PlaceSuggestion(
      id: stop.code,
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
