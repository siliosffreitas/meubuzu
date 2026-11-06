import 'dart:async';

import '../../../../../../domain/models/bus_stop.dart';
import '../../../../../../domain/models/user_coordinates.dart';
import '../../../../../../domain/repositories/user_location_repository.dart';
import '../../../../../../domain/contracts/contracts.dart';
import 'map_location_state.dart';

/// Acompanha a localização e as paradas próximas publicadas pelo
/// [UserLocationRepository].
///
/// Emite estados concretos ([MapLocationState]) para que a view saiba qual
/// conteúdo exibir sem depender de um enum de status.
class MapLocationViewModel extends ViewmodelBase {
  MapLocationViewModel(this._repository) {
    _subscription = _repository.location.listen(
      _handlePosition,
      onError: _handleError,
    );
    _nearbyStopsSubscription = _repository.nearbyStops.listen(
      _handleNearbyStops,
      onError: _handleNearbyStopsError,
    );
  }

  final UserLocationRepository _repository;
  late final StreamSubscription<UserCoordinates> _subscription;
  late final StreamSubscription<List<BusStop>> _nearbyStopsSubscription;

  MapLocationState _state = const MapLocationIdle();
  List<BusStop> _nearbyStops = const [];
  UserCoordinates? _latestPosition;

  /// Estado atual da localização exibido pela view.
  MapLocationState get state => _state;

  /// Coordenadas da localização atual (se houver).
  UserCoordinates? get position => _state.position;

  /// Paradas próximas que devem ser exibidas no mapa.
  List<BusStop> get nearbyStops => _state.nearbyStops;

  /// Indica se a localização está disponível.
  bool get isReady => _state.isReady;

  /// Pede ao repositório a localização atual do dispositivo.
  ///
  /// Use [requestPermission] como `false` para apenas revalidar o estado ao
  /// voltar das configurações, sem abrir o diálogo de permissão novamente.
  Future<void> initialize({bool requestPermission = true}) {
    _latestPosition = null;
    _nearbyStops = const [];
    _update(const MapLocationChecking());
    return _repository.refresh(requestPermission: requestPermission);
  }

  Future<void> openLocationSettings() => _repository.openLocationSettings();

  Future<void> openAppSettings() => _repository.openAppSettings();

  void _handlePosition(UserCoordinates position) {
    _latestPosition = position;
    _update(
      _nearbyStops.isEmpty
          ? MapLocationReady(position)
          : MapLocationNearbyStopsReady(
              position: position,
              nearbyStops: _nearbyStops,
            ),
    );
  }

  void _handleNearbyStops(List<BusStop> stops) {
    _nearbyStops = stops;
    final position = _latestPosition;
    if (position == null) {
      return;
    }
    _update(
      stops.isEmpty
          ? MapLocationReady(position)
          : MapLocationNearbyStopsReady(position: position, nearbyStops: stops),
    );
  }

  void _handleNearbyStopsError(Object error, StackTrace stackTrace) {
    // Uma falha no catálogo de paradas não invalida a localização atual.
    _nearbyStops = const [];
    final position = _latestPosition;
    if (position != null) {
      _update(MapLocationReady(position));
    }
  }

  void _handleError(Object error, StackTrace stackTrace) {
    _latestPosition = null;
    _nearbyStops = const [];
    _update(_stateFor(error));
  }

  static MapLocationState _stateFor(Object error) {
    if (error is! UserLocationException) {
      return const MapLocationUnavailable();
    }
    return switch (error.failure) {
      UserLocationFailure.noGpsHardware => const MapLocationNoGpsHardware(),
      UserLocationFailure.serviceDisabled => const MapLocationServiceDisabled(),
      UserLocationFailure.permissionDenied =>
        const MapLocationPermissionDenied(),
      UserLocationFailure.permissionDeniedForever =>
        const MapLocationPermissionDeniedForever(),
      UserLocationFailure.unavailable => const MapLocationUnavailable(),
    };
  }

  void _update(MapLocationState state) {
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    _nearbyStopsSubscription.cancel();
    super.dispose();
  }
}
