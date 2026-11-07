import 'dart:async';

import '../../domain/models/bus_stop.dart';
import '../../domain/models/line.dart';
import '../../domain/repositories/details_line_repository.dart';
import '../services/bus_stop_service.dart';
import '../services/line_search_service.dart';
import '../services/line_stops_service.dart';

/// Implementação baseada nos catálogos locais de linhas e paradas.
class DetailsLineRepositoryImpl implements DetailsLineRepository {
  DetailsLineRepositoryImpl(
    this._lineSearchService,
    this._lineStopsService,
    this._busStopService,
  );

  final LineSearchService _lineSearchService;
  final LineStopsService _lineStopsService;
  final BusStopService _busStopService;

  final StreamController<Line?> _currentLineController =
      StreamController<Line?>.broadcast();
  final StreamController<List<BusStop>> _busStopsController =
      StreamController<List<BusStop>>.broadcast();

  @override
  Stream<Line?> get currentLine => _currentLineController.stream;

  @override
  Stream<List<BusStop>> get busStops => _busStopsController.stream;

  @override
  Future<void> setCurrentLine(String lineCode) async {
    if (lineCode.isEmpty) {
      _currentLineController.add(null);
      _busStopsController.add(const []);
      return;
    }

    // Consulta o catálogo pelo código da linha para recuperar os dados básicos.
    final results = await _lineSearchService.search(lineCode);
    _currentLineController.add(results.isNotEmpty ? results.first : null);

    // Recupera os códigos das paradas que a linha passa e os seus dados.
    final stopCodes = await _lineStopsService.findStopCodesForLine(lineCode);
    final stops = await _busStopService.findByCodes(stopCodes);
    _busStopsController.add(stops);
  }

  @override
  void dispose() {
    _currentLineController.close();
    _busStopsController.close();
  }
}
