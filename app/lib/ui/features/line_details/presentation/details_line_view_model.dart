import 'dart:async';

import '../../../../domain/contracts/contracts.dart';
import '../../../../domain/models/bus_stop.dart';
import '../../../../domain/models/line.dart';
import '../../../../domain/models/tracked_line.dart';
import '../../../../domain/repositories/details_line_repository.dart';
import '../../../../domain/repositories/tracking_repository.dart';
import 'details_line_state.dart';

/// Acompanha a linha atual e suas paradas publicadas pelo
/// [DetailsLineRepository].
///
/// Emite estados concretos ([DetailsLineState]) para que a view saiba qual
/// conteúdo exibir sem depender de um enum de status. Também observa o
/// [TrackingRepository] para informar se a linha já está no mapa.
class DetailsLineViewModel extends ViewmodelBase {
  DetailsLineViewModel(
    this._repository, {
    required this.lineCode,
    required this.trackingRepository,
  }) {
    _lineSubscription = _repository.currentLine.listen(
      _handleLine,
      onError: _handleError,
    );
    _stopsSubscription = _repository.busStops.listen(
      _handleStops,
      onError: _handleError,
    );
    _trackingSubscription = trackingRepository.trackingRoutes.listen(
      _handleTrackedLines,
      onError: _handleTrackingError,
    );
  }

  final DetailsLineRepository _repository;
  final TrackingRepository trackingRepository;
  final String lineCode;

  late final StreamSubscription<Line?> _lineSubscription;
  late final StreamSubscription<List<BusStop>> _stopsSubscription;
  late final StreamSubscription<List<TrackedLine>> _trackingSubscription;

  DetailsLineState _state = const DetailsLineIdle();
  Line? _line;
  List<BusStop>? _stops;
  List<TrackedLine> _trackedLines = const [];
  bool _isTracking = false;
  bool _isDisposed = false;

  /// Estado atual da tela.
  DetailsLineState get state => _state;

  /// Indica se a linha já está sendo acompanhada no mapa.
  bool get isTracking => _isTracking;

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
    _refreshTrackingStatus();
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

  /// Atualiza se a linha desta tela está sendo acompanhada no mapa.
  void _handleTrackedLines(List<TrackedLine> trackedLines) {
    _trackedLines = trackedLines;
    _refreshTrackingStatus();
  }

  /// Recalcula o status com base na última lista de linhas acompanhadas.
  void _refreshTrackingStatus() {
    final isTracking = _trackedLines.any(_isCurrentLine);
    if (isTracking == _isTracking || _isDisposed) {
      return;
    }
    _isTracking = isTracking;
    notifyListeners();
  }

  /// Mantém o último status conhecido quando a atualização do mapa falha.
  void _handleTrackingError(Object error, StackTrace stackTrace) {}

  /// Verifica se [tracked] corresponde à linha desta tela.
  ///
  /// O código da rota pode ser o `sgLinha` exibido ou o código interno, então a
  /// comparação aceita ambos.
  bool _isCurrentLine(TrackedLine tracked) {
    final target = lineCode.trim();
    final boardingCode = tracked.line.boardingCode?.trim();
    final lineId = tracked.line.id.trim();
    return boardingCode == target ||
        lineId == target ||
        (_line != null && lineId == _line!.id.trim());
  }

  /// Código usado como chave pelo [TrackingRepository] ao iniciar/remover.
  String get _trackingCode {
    final boardingCode = _line?.boardingCode?.trim();
    if (boardingCode != null && boardingCode.isNotEmpty) {
      return boardingCode;
    }
    final id = _line?.id.trim();
    return id == null || id.isEmpty ? lineCode.trim() : id;
  }

  /// Remove a linha atual do mapa.
  Future<void> stopTracking() async {
    await trackingRepository.stopTracking(_trackingCode);
  }

  /// Inicia o acompanhamento da linha atual no mapa.
  Future<void> startTracking() async {
    await trackingRepository.startTracking(_trackingCode);
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
    _trackingSubscription.cancel();
    super.dispose();
  }
}
