import 'dart:async';

import '../../../../domain/contracts/contracts.dart';
import '../../../../domain/models/bus_stop.dart';
import '../../../../domain/models/favorite.dart';
import '../../../../domain/models/line.dart';
import '../../../../domain/models/tracked_line.dart';
import '../../../../domain/models/user_coordinates.dart';
import '../../../../domain/repositories/details_bus_stop_repository.dart';
import '../../../../domain/repositories/favorites_repository.dart';
import '../../../../domain/repositories/tracking_repository.dart';
import '../../../../domain/repositories/user_location_repository.dart';
import 'details_bus_stop_state.dart';

/// Acompanha a parada atual e as linhas que passam por ela, publicadas pelo
/// [DetailsBusStopRepository].
///
/// Emite estados concretos ([DetailsBusStopState]) para que a view saiba qual
/// conteúdo exibir. Quando recebe um [UserLocationRepository], também acompanha
/// a última localização disponível para calcular a distância até a parada, sem
/// solicitar permissão novamente. Quando recebe um [TrackingRepository],
/// acompanha quais linhas já estão sendo rastreadas no mapa.
class DetailsBusStopViewModel extends ViewmodelBase {
  DetailsBusStopViewModel(
    this._repository, {
    required this.busStopCode,
    UserLocationRepository? locationRepository,
    TrackingRepository? trackingRepository,
    FavoritesRepository? favoritesRepository,
  }) : _favoritesRepository = favoritesRepository {
    _trackingSubscription = trackingRepository?.trackingRoutes.listen(
      _handleTrackedLines,
      onError: _handleTrackingError,
    );
    _favoritesSubscription = favoritesRepository?.favorites.listen(
      _handleFavorites,
      onError: _handleFavoritesError,
    );
    unawaited(favoritesRepository?.refresh().catchError((Object _) {}));
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
  final FavoritesRepository? _favoritesRepository;
  final String busStopCode;

  late final StreamSubscription<BusStop?> _busStopSubscription;
  late final StreamSubscription<List<Line>> _linesSubscription;
  StreamSubscription<UserCoordinates>? _locationSubscription;
  StreamSubscription<List<TrackedLine>>? _trackingSubscription;
  StreamSubscription<List<Favorite>>? _favoritesSubscription;

  DetailsBusStopState _state = const DetailsBusStopIdle();
  BusStop? _busStop;
  List<Line>? _lines;
  UserCoordinates? _position;
  Set<String> _trackedLineCodes = const {};
  Set<String> _favoriteLineIds = const {};
  bool _isDisposed = false;

  /// Estado atual da tela.
  DetailsBusStopState get state => _state;

  /// Códigos (`sgLinha`) das linhas já acompanhadas no mapa.
  Set<String> get trackedLineCodes => _trackedLineCodes;

  /// IDs das linhas favoritas, para exibir a estrela preenchida.
  Set<String> get favoriteLineIds => _favoriteLineIds;

  /// A estrela aparece apenas quando há um repositório de favoritos disponível.
  bool get hasFavorites => _favoritesRepository != null;

  /// Alterna o favorito da linha [lineId].
  Future<void> toggleFavorite(String lineId) async {
    await _favoritesRepository?.toggle(lineId);
  }

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

  void _handleTrackedLines(List<TrackedLine> trackedLines) {
    _trackedLineCodes = {
      for (final tracked in trackedLines) _searchCode(tracked.line),
    };
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void _handleTrackingError(Object error, StackTrace stackTrace) {
    _trackedLineCodes = const {};
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void _handleFavorites(List<Favorite> favorites) {
    _favoriteLineIds = {for (final favorite in favorites) favorite.lineId};
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void _handleFavoritesError(Object error, StackTrace stackTrace) {
    _favoriteLineIds = const {};
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Código usado na busca (`sgLinha`), com fallback para o código interno.
  String _searchCode(Line line) {
    final boardingCode = line.boardingCode?.trim();
    return boardingCode != null && boardingCode.isNotEmpty
        ? boardingCode
        : line.id.trim();
  }

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
    _trackingSubscription?.cancel();
    _favoritesSubscription?.cancel();
    super.dispose();
  }
}
