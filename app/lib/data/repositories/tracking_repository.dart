import 'dart:async';

import '../../domain/models/bus_position.dart';
import '../../domain/models/line.dart';
import '../../domain/models/line_direction.dart';
import '../../domain/models/tracked_line.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../services/line_directions_service.dart';
import '../services/line_search_service.dart';
import '../services/route_service.dart';
import '../services/tracking_service.dart';

/// Implementação que monta as linhas acompanhadas a partir do catálogo local e
/// dos traçados em CSV.
///
/// Enquanto houver linhas acompanhadas, consulta o [TrackingService] a cada
/// [pollInterval] para atualizar as posições dos ônibus. Cada nova linha
/// adicionada dispara uma consulta com todas as linhas acompanhadas (inclusive
/// a nova) e reinicia o cronômetro.
class TrackingRepositoryImpl implements TrackingRepository {
  TrackingRepositoryImpl(
    this._routeService,
    this._lineSearchService, {
    LineDirectionsService? directionsService,
    this.trackingService,
    this.pollInterval = const Duration(seconds: 30),
  }) : _directionsService =
           directionsService ?? const EmptyLineDirectionsService();

  final RouteService _routeService;
  final LineSearchService _lineSearchService;
  final LineDirectionsService _directionsService;

  /// Serviço que fornece as posições dos ônibus, quando disponível.
  final TrackingService? trackingService;

  /// Intervalo entre as consultas de posições.
  final Duration pollInterval;

  final StreamController<List<TrackedLine>> _trackingController =
      StreamController<List<TrackedLine>>.broadcast();

  final Map<String, TrackedLine> _trackedLines = <String, TrackedLine>{};
  final Set<String> _pendingLines = <String>{};
  final Set<String> _pendingDirections = <String>{};

  List<TrackedLine> _latestRoutes = const [];

  Timer? _pollTimer;
  Future<void>? _inFlightRefresh;

  bool _isDisposed = false;

  @override
  Stream<List<TrackedLine>> get trackingRoutes {
    return Stream<List<TrackedLine>>.multi((controller) {
      controller.add(_latestRoutes);
      final subscription = _trackingController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<TrackedLine?> startTracking(String lineCode) async {
    final normalized = lineCode.trim();
    if (normalized.isEmpty || _isDisposed) {
      return null;
    }

    final existing = _trackedLines[normalized];
    if (existing != null) {
      return existing;
    }
    if (!_pendingLines.add(normalized)) {
      return null;
    }

    try {
      final line = await _findLine(normalized);
      if (line == null || _isDisposed) {
        return null;
      }

      final directions = await _loadDirections(normalized);
      if (_isDisposed) {
        return null;
      }
      final direction = _initialDirection(directions);
      final route = await _routeService.findRoute(
        normalized,
        direction: direction,
      );
      if (_isDisposed) {
        return null;
      }

      _trackedLines[normalized] = TrackedLine(
        line: line,
        route: route,
        busPositions: const [],
        direction: direction,
        directions: directions,
      );

      // Reinicia o cronômetro a partir da adição e consulta todas as linhas
      // acompanhadas de uma vez, incluindo a recém-adicionada.
      _restartPolling();
      await _refreshAfterAdd();
      if (_isDisposed) {
        return null;
      }
      return _trackedLines[normalized];
    } finally {
      _pendingLines.remove(normalized);
    }
  }

  @override
  Future<TrackedLine?> changeDirection(String lineCode, int direction) async {
    final normalized = lineCode.trim();
    if (normalized.isEmpty || _isDisposed) {
      return null;
    }

    final current = _trackedLines[normalized];
    if (current == null) {
      return null;
    }
    if (current.direction == direction) {
      return current;
    }
    if (!_pendingDirections.add(normalized)) {
      return null;
    }

    try {
      final route = await _routeService.findRoute(
        normalized,
        direction: direction,
      );
      if (_isDisposed) {
        return null;
      }

      // A linha pode ter sido removida enquanto o traçado era carregado.
      final latest = _trackedLines[normalized];
      if (latest == null) {
        return null;
      }

      final updated = TrackedLine(
        line: latest.line,
        route: route,
        busPositions: latest.busPositions,
        direction: direction,
        directions: latest.directions,
      );
      _trackedLines[normalized] = updated;
      _publish();
      return updated;
    } finally {
      _pendingDirections.remove(normalized);
    }
  }

  @override
  Future<void> stopTracking(String lineCode) async {
    if (_isDisposed) {
      return;
    }
    final normalized = lineCode.trim();
    if (_trackedLines.remove(normalized) != null) {
      _publish();
      if (_trackedLines.isEmpty) {
        _cancelPolling();
      }
    }
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _cancelPolling();
    _trackedLines.clear();
    _pendingLines.clear();
    _pendingDirections.clear();
    _latestRoutes = const [];
    _trackingController.close();
  }

  /// Busca a linha no catálogo, priorizando correspondência exata ao `sgLinha`.
  Future<Line?> _findLine(String lineCode) async {
    final results = await _lineSearchService.search(lineCode);
    for (final line in results) {
      if (line.publicCode == lineCode) {
        return line;
      }
    }
    return results.isNotEmpty ? results.first : null;
  }

  /// Carrega os sentidos sem impedir o rastreamento quando a consulta falha.
  Future<List<LineDirection>> _loadDirections(String lineCode) async {
    try {
      return await _directionsService.findDirections(lineCode);
    } catch (_) {
      return const [];
    }
  }

  /// Sentido inicial: o primeiro com traçado ou, na falta dele, o primeiro.
  int _initialDirection(List<LineDirection> directions) {
    for (final direction in directions) {
      if (direction.hasRoute) {
        return direction.value;
      }
    }
    return directions.isNotEmpty ? directions.first.value : 0;
  }

  void _restartPolling() {
    _cancelPolling();
    if (_isDisposed || trackingService == null || _trackedLines.isEmpty) {
      return;
    }
    _pollTimer = Timer.periodic(pollInterval, (_) => _refresh());
  }

  void _cancelPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Consulta usada pelo cronômetro. Não empilha consultas sobrepostas.
  Future<void> _refresh() {
    return _inFlightRefresh ??= _doRefresh().whenComplete(() {
      _inFlightRefresh = null;
    });
  }

  /// Consulta disparada ao adicionar uma linha.
  ///
  /// Aguarda uma consulta em andamento (que ainda não conhece a linha nova) e
  /// então consulta novamente com todas as linhas acompanhadas.
  Future<void> _refreshAfterAdd() async {
    final running = _inFlightRefresh;
    if (running != null) {
      await running;
    }
    if (_isDisposed) {
      return;
    }
    await _refresh();
  }

  Future<void> _doRefresh() async {
    final service = trackingService;
    if (service == null) {
      _publish();
      return;
    }
    if (_isDisposed || _trackedLines.isEmpty) {
      return;
    }

    try {
      final entries = _trackedLines.entries.toList(growable: false);
      final lines = [for (final entry in entries) entry.value.line];
      final positions = await service.findPositions(lines);
      if (_isDisposed) {
        return;
      }

      final byLineCode = <String, List<BusPosition>>{};
      for (final position in positions) {
        final code = normalizeLineCode(position.lineCode);
        if (code.isEmpty) {
          continue;
        }
        (byLineCode[code] ??= <BusPosition>[]).add(position);
      }

      for (final entry in entries) {
        final key = entry.key;
        // A linha pode ter saído do acompanhamento durante a consulta.
        final current = _trackedLines[key];
        if (current == null) {
          continue;
        }
        final code = normalizeLineCode(current.line.publicCode);
        _trackedLines[key] = TrackedLine(
          line: current.line,
          route: current.route,
          busPositions: byLineCode[code] ?? const <BusPosition>[],
          direction: current.direction,
          directions: current.directions,
        );
      }
    } catch (_) {
      // Mantém as últimas posições conhecidas quando a consulta falha.
    }

    if (_isDisposed) {
      return;
    }
    _publish();
  }

  void _publish() {
    if (_isDisposed) {
      return;
    }
    _latestRoutes = List<TrackedLine>.unmodifiable(_trackedLines.values);
    _trackingController.add(_latestRoutes);
  }
}
