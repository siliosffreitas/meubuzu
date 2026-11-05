import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/user_coordinates.dart';
import '../data/user_location_repository.dart';

/// Etapas da obtenção da localização do usuário.
enum MapLocationStatus {
  idle,
  checking,
  noGpsHardware,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
  ready,
}

/// Acompanha a localização publicada pelo [UserLocationRepository].
class MapLocationViewModel extends ChangeNotifier {
  MapLocationViewModel(this._repository) {
    _subscription = _repository.location.listen(
      _handlePosition,
      onError: _handleError,
    );
  }

  final UserLocationRepository _repository;
  late final StreamSubscription<UserCoordinates> _subscription;

  MapLocationStatus _status = MapLocationStatus.idle;
  UserCoordinates? _position;

  MapLocationStatus get status => _status;
  UserCoordinates? get position => _position;
  bool get isReady => _status == MapLocationStatus.ready;

  /// Pede ao repositório a localização atual do dispositivo.
  ///
  /// Use [requestPermission] como `false` para apenas revalidar o estado ao
  /// voltar das configurações, sem abrir o diálogo de permissão novamente.
  Future<void> initialize({bool requestPermission = true}) {
    _position = null;
    _update(MapLocationStatus.checking);
    return _repository.refresh(requestPermission: requestPermission);
  }

  Future<void> openLocationSettings() => _repository.openLocationSettings();

  Future<void> openAppSettings() => _repository.openAppSettings();

  void _handlePosition(UserCoordinates position) {
    _position = position;
    _update(MapLocationStatus.ready);
  }

  void _handleError(Object error, StackTrace stackTrace) {
    _position = null;
    _update(_statusFor(error));
  }

  static MapLocationStatus _statusFor(Object error) {
    if (error is! UserLocationException) {
      return MapLocationStatus.unavailable;
    }
    return switch (error.failure) {
      UserLocationFailure.noGpsHardware => MapLocationStatus.noGpsHardware,
      UserLocationFailure.serviceDisabled => MapLocationStatus.serviceDisabled,
      UserLocationFailure.permissionDenied =>
        MapLocationStatus.permissionDenied,
      UserLocationFailure.permissionDeniedForever =>
        MapLocationStatus.permissionDeniedForever,
      UserLocationFailure.unavailable => MapLocationStatus.unavailable,
    };
  }

  void _update(MapLocationStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
