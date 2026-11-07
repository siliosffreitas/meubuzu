import 'dart:async';

import '../../../../domain/contracts/contracts.dart';
import '../../../../domain/models/bus_stop.dart';
import '../../../../domain/models/line.dart';
import '../../../../domain/repositories/details_line_repository.dart';
import 'details_line_state.dart';

/// Acompanha a linha atual e suas paradas publicadas pelo
/// [DetailsLineRepository].
///
/// Emite estados concretos ([DetailsLineState]) para que a view saiba qual
/// conteúdo exibir sem depender de um enum de status.
class DetailsLineViewModel extends ViewmodelBase {
  DetailsLineViewModel(this._repository, {required this.lineCode}) {
    _lineSubscription = _repository.currentLine.listen(
      _handleLine,
      onError: _handleError,
    );
    _stopsSubscription = _repository.busStops.listen(
      _handleStops,
      onError: _handleError,
    );
  }

  final DetailsLineRepository _repository;
  final String lineCode;

  late final StreamSubscription<Line?> _lineSubscription;
  late final StreamSubscription<List<BusStop>> _stopsSubscription;

  DetailsLineState _state = const DetailsLineIdle();
  Line? _line;
  List<BusStop>? _stops;
  bool _isDisposed = false;

  /// Estado atual da tela.
  DetailsLineState get state => _state;

  /// Inicia o carregamento da linha e das paradas.
  Future<void> load() async {
    _line = null;
    _stops = null;
    _update(const DetailsLineLoading());

    try {
      await _repository.setCurrentLine(lineCode);
    } catch (_) {
      _update(const DetailsLineError());
    }
  }

  void _handleLine(Line? line) {
    _line = line;
    if (line == null) {
      _stops = const [];
      _update(const DetailsLineNotFound());
      return;
    }

    final stops = _stops;
    if (stops == null) {
      return;
    }
    _emitLineAndStops(line, stops);
  }

  void _handleStops(List<BusStop> stops) {
    _stops = stops;
    final line = _line;
    if (line == null) {
      return;
    }
    _emitLineAndStops(line, stops);
  }

  void _emitLineAndStops(Line line, List<BusStop> stops) {
    _update(
      stops.isEmpty
          ? DetailsLineNoStops(line)
          : DetailsLineReady(line: line, stops: stops),
    );
  }

  void _handleError(Object error, StackTrace stackTrace) {
    _update(const DetailsLineError());
  }

  void _update(DetailsLineState state) {
    if (_isDisposed) {
      return;
    }
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _lineSubscription.cancel();
    _stopsSubscription.cancel();
    super.dispose();
  }
}
