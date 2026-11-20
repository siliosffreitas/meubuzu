import 'dart:async';

import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/domain/models/tracked_line.dart';
import 'package:meubuzu/domain/repositories/tracking_repository.dart';

/// Repositório de rastreamento em memória usado nos testes.
///
/// Entrega o estado atual para cada novo ouvinte e registra as chamadas de
/// início e remoção.
class FakeTrackingRepository implements TrackingRepository {
  FakeTrackingRepository({List<TrackedLine> trackedLines = const []})
    : _current = List<TrackedLine>.unmodifiable(trackedLines);

  final StreamController<List<TrackedLine>> _controller =
      StreamController<List<TrackedLine>>.broadcast();

  final List<String> startedCodes = <String>[];
  final List<String> stoppedCodes = <String>[];

  List<TrackedLine> _current;
  bool _isDisposed = false;

  @override
  Stream<List<TrackedLine>> get trackingRoutes async* {
    yield _current;
    yield* _controller.stream;
  }

  /// Substitui as linhas acompanhadas e notifica os ouvintes.
  void emit(List<TrackedLine> trackedLines) {
    _current = List<TrackedLine>.unmodifiable(trackedLines);
    _controller.add(_current);
  }

  /// Adiciona ou atualiza a linha acompanhada [tracked].
  void emitLine(TrackedLine tracked) {
    final key = _key(tracked.line);
    emit([
      for (final current in _current)
        if (_key(current.line) != key) current,
      tracked,
    ]);
  }

  @override
  Future<TrackedLine?> startTracking(String lineCode) async {
    final normalized = lineCode.trim();
    startedCodes.add(normalized);
    for (final tracked in _current) {
      if (_key(tracked.line) == normalized) {
        return tracked;
      }
    }
    return null;
  }

  @override
  Future<void> stopTracking(String lineCode) async {
    final normalized = lineCode.trim();
    stoppedCodes.add(normalized);
    emit([
      for (final tracked in _current)
        if (_key(tracked.line) != normalized) tracked,
    ]);
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _controller.close();
  }

  String _key(Line line) => line.publicCode;
}

/// Cria uma linha acompanhada sem traçado nem ônibus, para testes de status.
TrackedLine trackedLineFor(Line line) {
  return TrackedLine(line: line, route: null, busPositions: const []);
}
