import 'dart:async';

import '../../domain/models/bus_position.dart';
import '../../domain/models/line.dart';
import '../../domain/models/tracked_line.dart';
import '../../domain/repositories/tracking_repository.dart';
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
    this.trackingService,
    this.pollInterval = const Duration(seconds: 30),
  });

  final RouteService _routeService;
  final LineSearchService _lineSearchService;

  /// Serviço que fornece as posições dos ônibus, quando disponível.
  final TrackingService? trackingService;

  /// Intervalo entre as consultas de posições.
  final Duration pollInterval;

  final StreamController<List<TrackedLine>> _trackingController =
      StreamController<List<TrackedLine>>.broadcast();

  final Map<String, TrackedLine> _trackedLines = <String, TrackedLine>{};
  final Set<String> _pendingLines = <String>{};

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

      final route = await _routeService.findRoute(normalized);
      if (_isDisposed) {
        return null;
      }

      _trackedLines[normalized] = TrackedLine(
        line: line,
        route: route,
        busPositions: const [],
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
