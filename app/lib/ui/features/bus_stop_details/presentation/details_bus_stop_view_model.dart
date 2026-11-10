import 'dart:async';

import '../../../../domain/contracts/contracts.dart';
import '../../../../domain/models/bus_stop.dart';
import '../../../../domain/models/line.dart';
import '../../../../domain/models/user_coordinates.dart';
import '../../../../domain/repositories/details_bus_stop_repository.dart';
import '../../../../domain/repositories/user_location_repository.dart';
import 'details_bus_stop_state.dart';

/// Acompanha a parada atual e as linhas que passam por ela, publicadas pelo
/// [DetailsBusStopRepository].
///
/// Emite estados concretos ([DetailsBusStopState]) para que a view saiba qual
/// conteúdo exibir. Quando recebe um [UserLocationRepository], também acompanha
/// a última localização disponível para calcular a distância até a parada, sem
/// solicitar permissão novamente.
class DetailsBusStopViewModel extends ViewmodelBase {
  DetailsBusStopViewModel(
    this._repository, {
    required this.busStopCode,
    UserLocationRepository? locationRepository,
  }) {
    _busStopSubscription = _repository.currentBusStop.listen(
      _handleBusStop,
      onError: _handleError,
    );
    _linesSubscription = _repository.lines.listen(
      _handleLines,
      onError: _handleError,
    );
    _locationSubscription = locationRepository?.location.listen(
      _handlePosition,
      onError: _handleLocationError,
    );
  }

  final DetailsBusStopRepository _repository;
  final String busStopCode;

  late final StreamSubscription<BusStop?> _busStopSubscription;
  late final StreamSubscription<List<Line>> _linesSubscription;
  late final StreamSubscription<UserCoordinates>? _locationSubscription;

  DetailsBusStopState _state = const DetailsBusStopIdle();
  BusStop? _busStop;
  List<Line>? _lines;
  UserCoordinates? _position;
  bool _isDisposed = false;

  /// Estado atual da tela.
  DetailsBusStopState get state => _state;

  /// Distância em metros até a parada, quando a localização está disponível.
  double? get distanceInMeters {
    final busStop = _state.busStop;
    final position = _position;
    if (busStop == null || position == null) {
      return null;
    }
    return busStop.distanceInMetersTo(position);
  }

  /// Inicia o carregamento da parada e das linhas que passam por ela.
  Future<void> load() async {
    _busStop = null;
    _lines = null;
    _update(const DetailsBusStopLoading());

    try {
      await _repository.setCurrentBusStop(busStopCode);
    } catch (_) {
      _update(const DetailsBusStopError());
    }
  }

  void _handleBusStop(BusStop? busStop) {
    _busStop = busStop;
    if (busStop == null) {
      _update(const DetailsBusStopNotFound());
      return;
    }
    _emitReadyIfComplete();
  }

  void _handleLines(List<Line> lines) {
    _lines = lines;
    _emitReadyIfComplete();
  }

  /// Publica o estado pronto apenas quando parada e linhas já chegaram.
  void _emitReadyIfComplete() {
    final busStop = _busStop;
    final lines = _lines;
    if (busStop == null || lines == null) {
      return;
    }
    _update(DetailsBusStopReady(busStop: busStop, lines: lines));
  }

  void _handleError(Object error, StackTrace stackTrace) {
    _update(const DetailsBusStopError());
  }

  void _handlePosition(UserCoordinates position) {
    _position = position;
    if (_isDisposed || _state.busStop == null) {
      return;
    }
    notifyListeners();
  }

  /// Mantém a tela sem distância quando a localização não está disponível.
  void _handleLocationError(Object error, StackTrace stackTrace) {}

  void _update(DetailsBusStopState state) {
    if (_isDisposed) {
      return;
    }
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _busStopSubscription.cancel();
    _linesSubscription.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }
}
