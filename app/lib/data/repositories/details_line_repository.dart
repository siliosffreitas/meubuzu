import 'dart:async';

import '../../domain/models/bus_stop.dart';
import '../../domain/models/line.dart';
import '../../domain/repositories/details_line_repository.dart';
import '../services/line_search_service.dart';

/// Implementação baseada no catálogo local de linhas.
class DetailsLineRepositoryImpl implements DetailsLineRepository {
  DetailsLineRepositoryImpl(this._lineSearchService);

  final LineSearchService _lineSearchService;

  final StreamController<Line?> _currentLineController =
      StreamController<Line?>.broadcast();
  final StreamController<BusStop?> _busStopsController =
      StreamController<BusStop?>.broadcast();

  @override
  Stream<Line?> get currentLine => _currentLineController.stream;

  @override
  Stream<BusStop?> get busStops => _busStopsController.stream;

  @override
  Future<void> setCurrentLine(Line line) async {
    final sgLinha = line.boardingCode;
    if (sgLinha == null || sgLinha.isEmpty) {
      _currentLineController.add(line);
      return;
    }

    // Consulta o catálogo pelo sgLinha para recuperar os dados básicos.
    final results = await _lineSearchService.search(sgLinha);
    _currentLineController.add(results.isNotEmpty ? results.first : line);
  }

  @override
  void dispose() {
    _currentLineController.close();
    _busStopsController.close();
  }
}
