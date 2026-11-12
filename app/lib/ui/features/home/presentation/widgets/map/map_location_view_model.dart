import 'dart:async';

import '../../../../../../domain/models/bus_stop.dart';
import '../../../../../../domain/models/user_coordinates.dart';
import '../../../../../../domain/repositories/user_location_repository.dart';
import '../../../../../../domain/contracts/contracts.dart';
import 'map_location_state.dart';

/// Zoom mínimo para consultar e exibir as paradas da área visível.
///
/// Abaixo desse nível o mapa mostra uma região grande demais e os marcadores
/// perdem utilidade; ao se aproximar, as paradas da área voltam a aparecer.
const double minVisibleStopsZoom = 14.5;

/// Acompanha a localização e as paradas da área visível publicadas pelo
/// [UserLocationRepository].
///
/// Emite estados concretos ([MapLocationState]) para que a view saiba qual
/// conteúdo exibir sem depender de um enum de status. As paradas da área
/// visível são independentes da localização: o mapa pode exibi-las mesmo sem
/// permissão de GPS.
class MapLocationViewModel extends ViewmodelBase {
  MapLocationViewModel(this._repository) {
    _subscription = _repository.location.listen(
      _handlePosition,
      onError: _handleError,
    );
    _visibleStopsSubscription = _repository.visibleStops.listen(
      _handleVisibleStops,
      onError: _handleVisibleStopsError,
    );
  }

  final UserLocationRepository _repository;
  late final StreamSubscription<UserCoordinates> _subscription;
  late final StreamSubscription<List<BusStop>> _visibleStopsSubscription;

  MapLocationState _state = const MapLocationIdle();
  List<BusStop> _visibleStops = const [];

  /// Estado atual da localização exibido pela view.
  MapLocationState get state => _state;

  /// Coordenadas da localização atual (se houver).
  UserCoordinates? get position => _state.position;

  /// Paradas que devem ser exibidas na área visível do mapa.
  List<BusStop> get visibleStops => _visibleStops;

  /// Indica se a localização está disponível.
  bool get isReady => _state.isReady;

  /// Pede ao repositório a localização atual do dispositivo.
  ///
  /// Use [requestPermission] como `false` para apenas revalidar o estado ao
  /// voltar das configurações, sem abrir o diálogo de permissão novamente.
  Future<void> initialize({bool requestPermission = true}) {
    _update(const MapLocationChecking());
    return _repository.refresh(requestPermission: requestPermission);
  }

  /// Atualiza a área visível do mapa e publica as paradas contidas nela.
  ///
  /// Quando [zoom] fica abaixo de [minVisibleStopsZoom], as paradas são
  /// limpas em vez de consultadas.
  Future<void> updateVisibleArea({
    required UserCoordinates southwest,
    required UserCoordinates northeast,
    required double zoom,
  }) async {
    if (zoom < minVisibleStopsZoom) {
      clearVisibleStops();
      return;
    }
    await _repository.updateVisibleArea(
      southwest: southwest,
      northeast: northeast,
    );
  }

  /// Limpa as paradas da área visível.
  void clearVisibleStops() {
    _repository.clearVisibleStops();
  }

  Future<void> openLocationSettings() => _repository.openLocationSettings();

  Future<void> openAppSettings() => _repository.openAppSettings();

  void _handlePosition(UserCoordinates position) {
    _update(MapLocationReady(position));
  }

  void _handleVisibleStops(List<BusStop> stops) {
    _visibleStops = stops;
    notifyListeners();
  }

  void _handleVisibleStopsError(Object error, StackTrace stackTrace) {
    // Uma falha no catálogo de paradas não invalida a localização atual nem
    // descarta as paradas já exibidas.
  }

  void _handleError(Object error, StackTrace stackTrace) {
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
    _visibleStopsSubscription.cancel();
    super.dispose();
  }
}
