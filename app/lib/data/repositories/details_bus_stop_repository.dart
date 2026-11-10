import 'dart:async';

import '../../domain/models/bus_stop.dart';
import '../../domain/models/line.dart';
import '../../domain/repositories/details_bus_stop_repository.dart';
import '../services/bus_stop_service.dart';
import '../services/line_search_service.dart';
import '../services/line_stops_service.dart';

/// Implementação baseada nos catálogos locais de paradas e linhas.
class DetailsBusStopRepositoryImpl implements DetailsBusStopRepository {
  DetailsBusStopRepositoryImpl(
    this._busStopService,
    this._lineStopsService,
    this._lineSearchService,
  );

  final BusStopService _busStopService;
  final LineStopsService _lineStopsService;
  final LineSearchService _lineSearchService;

  final StreamController<BusStop?> _currentBusStopController =
      StreamController<BusStop?>.broadcast();
  final StreamController<List<Line>> _linesController =
      StreamController<List<Line>>.broadcast();

  @override
  Stream<BusStop?> get currentBusStop => _currentBusStopController.stream;

  @override
  Stream<List<Line>> get lines => _linesController.stream;

  @override
  Future<void> setCurrentBusStop(String busStopCode) async {
    final normalized = busStopCode.trim();
    if (normalized.isEmpty) {
      _currentBusStopController.add(null);
      _linesController.add(const []);
      return;
    }

    // Recupera os dados básicos da parada no catálogo.
    final stops = await _busStopService.findByCodes([normalized]);
    final busStop = stops.isNotEmpty ? stops.first : null;
    _currentBusStopController.add(busStop);

    if (busStop == null) {
      _linesController.add(const []);
      return;
    }

    // Recupera os códigos das linhas que passam na parada e os seus dados.
    final lineCodes = await _lineStopsService.findLineCodesForStop(normalized);
    final lines = await _lineSearchService.findByCodes(lineCodes);
    _linesController.add(_sortByDisplayCode(lines));
  }

  /// Ordena as linhas pelo código exibido (`sgLinha`, com fallback para o id).
  List<Line> _sortByDisplayCode(List<Line> lines) {
    final sorted = [...lines]..sort(_compareLines);
    return List<Line>.unmodifiable(sorted);
  }

  int _compareLines(Line first, Line second) {
    final codeComparison = _displayCode(first)
        .toLowerCase()
        .compareTo(_displayCode(second).toLowerCase());
    if (codeComparison != 0) {
      return codeComparison;
    }
    return first.name.toLowerCase().compareTo(second.name.toLowerCase());
  }

  String _displayCode(Line line) {
    final boardingCode = line.boardingCode?.trim();
    return boardingCode != null && boardingCode.isNotEmpty
        ? boardingCode
        : line.id.trim();
  }

  @override
  void dispose() {
    _currentBusStopController.close();
    _linesController.close();
  }
}
