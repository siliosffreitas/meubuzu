import 'dart:async';

import '../../../../../../data/models/user_coordinates.dart';
import '../../../../../../domain/repositories/user_location_repository.dart';
import '../../../../../../domain/contracts/contracts.dart';
import 'map_location_state.dart';

/// Acompanha a localização publicada pelo [UserLocationRepository].
///
/// Emite estados concretos ([MapLocationState]) para que a view saiba qual
/// conteúdo exibir sem depender de um enum de status.
class MapLocationViewModel extends ViewmodelBase {
  MapLocationViewModel(this._repository) {
    _subscription = _repository.location.listen(
      _handlePosition,
      onError: _handleError,
    );
  }

  final UserLocationRepository _repository;
  late final StreamSubscription<UserCoordinates> _subscription;

  MapLocationState _state = const MapLocationIdle();

  /// Estado atual da localização exibido pela view.
  MapLocationState get state => _state;

  /// Coordenadas da localização atual (se houver).
  UserCoordinates? get position => _state.position;

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

  Future<void> openLocationSettings() => _repository.openLocationSettings();

  Future<void> openAppSettings() => _repository.openAppSettings();

  void _handlePosition(UserCoordinates position) {
    _update(MapLocationReady(position));
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
    super.dispose();
  }
}
