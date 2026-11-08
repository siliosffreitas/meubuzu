import 'dart:async';

import '../../domain/models/line.dart';
import '../../domain/models/tracked_line.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../services/line_search_service.dart';
import '../services/route_service.dart';

/// Implementação que monta as linhas acompanhadas a partir do catálogo local e
/// dos traçados em CSV.
class TrackingRepositoryImpl implements TrackingRepository {
  TrackingRepositoryImpl(this._routeService, this._lineSearchService);

  final RouteService _routeService;
  final LineSearchService _lineSearchService;

  final StreamController<List<TrackedLine>> _trackingController =
      StreamController<List<TrackedLine>>.broadcast();

  final Map<String, TrackedLine> _trackedLines = <String, TrackedLine>{};
  final Set<String> _pendingLines = <String>{};

  List<TrackedLine> _latestRoutes = const [];

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
  Future<void> startTracking(String lineCode) async {
    final normalized = lineCode.trim();
    if (normalized.isEmpty || _trackedLines.containsKey(normalized)) {
      return;
    }
    if (!_pendingLines.add(normalized)) {
      return;
    }

    try {
      final line = await _findLine(normalized);
      if (line == null || _isDisposed) {
        return;
      }

      final route = await _routeService.findRoute(normalized);
      if (_isDisposed) {
        return;
      }

      _trackedLines[normalized] = TrackedLine(
        line: line,
        route: route,
        busPositions: const [],
      );
      _publish();
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
    }
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _trackedLines.clear();
    _pendingLines.clear();
    _latestRoutes = const [];
    _trackingController.close();
  }

  /// Busca a linha no catálogo, priorizando correspondência exata ao `sgLinha`.
  Future<Line?> _findLine(String lineCode) async {
    final results = await _lineSearchService.search(lineCode);
    for (final line in results) {
      if (line.boardingCode?.trim() == lineCode) {
        return line;
      }
    }
    return results.isNotEmpty ? results.first : null;
  }

  void _publish() {
    if (_isDisposed) {
      return;
    }
    _latestRoutes = List<TrackedLine>.unmodifiable(_trackedLines.values);
    _trackingController.add(_latestRoutes);
  }
}
