import 'dart:async';

import 'location_service.dart';
import 'user_coordinates.dart';

/// Motivos pelos quais a localização do usuário não pôde ser obtida.
enum UserLocationFailure {
  noGpsHardware,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

/// Erro publicado em [UserLocationRepository.location].
class UserLocationException implements Exception {
  const UserLocationException(this.failure);

  final UserLocationFailure failure;

  @override
  String toString() => 'UserLocationException($failure)';
}

/// Contrato de acesso à localização do usuário.
abstract interface class UserLocationRepository {
  /// Localização atual do usuário e suas atualizações.
  ///
  /// A última posição obtida é reemitida para novos ouvintes. Quando a
  /// localização não pode ser obtida, o stream publica um
  /// [UserLocationException].
  Stream<UserCoordinates> get location;

  /// Busca a localização atual no dispositivo.
  ///
  /// Executa a sequência hardware de GPS → serviço ligado → permissão →
  /// posição. Use [requestPermission] como `false` para apenas revalidar o
  /// estado, sem abrir o diálogo de permissão novamente.
  Future<void> refresh({bool requestPermission = true});

  /// Abre as configurações de localização do sistema.
  Future<void> openLocationSettings();

  /// Abre as configurações do próprio app.
  Future<void> openAppSettings();

  /// Libera os recursos do repositório.
  void dispose();
}

/// Implementação baseada na localização do dispositivo.
class DeviceUserLocationRepository implements UserLocationRepository {
  DeviceUserLocationRepository(this._service);

  final LocationService _service;
  final _positions = StreamController<UserCoordinates>.broadcast();

  UserCoordinates? _latestPosition;
  bool _isRefreshing = false;

  @override
  Stream<UserCoordinates> get location {
    return Stream<UserCoordinates>.multi((controller) {
      final latest = _latestPosition;
      if (latest != null) {
        controller.add(latest);
      }
      final subscription = _positions.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<void> refresh({bool requestPermission = true}) async {
    if (_isRefreshing) {
      return;
    }
    _isRefreshing = true;

    try {
      final hasGps = await _service.hasGpsHardware();
      if (!hasGps) {
        _publishFailure(UserLocationFailure.noGpsHardware);
        return;
      }

      final serviceEnabled = await _service.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _publishFailure(UserLocationFailure.serviceDisabled);
        return;
      }

      var permission = await _service.checkPermission();
      if (permission == LocationPermissionStatus.denied && requestPermission) {
        permission = await _service.requestPermission();
      }
      if (permission != LocationPermissionStatus.granted) {
        _publishFailure(
          permission == LocationPermissionStatus.deniedForever
              ? UserLocationFailure.permissionDeniedForever
              : UserLocationFailure.permissionDenied,
        );
        return;
      }

      final position = await _service.currentPosition();
      if (position == null) {
        _publishFailure(UserLocationFailure.unavailable);
        return;
      }

      _latestPosition = position;
      _positions.add(position);
    } catch (_) {
      _publishFailure(UserLocationFailure.unavailable);
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  Future<void> openLocationSettings() => _service.openLocationSettings();

  @override
  Future<void> openAppSettings() => _service.openAppSettings();

  @override
  void dispose() {
    _positions.close();
  }

  void _publishFailure(UserLocationFailure failure) {
    _positions.addError(UserLocationException(failure));
  }
}
