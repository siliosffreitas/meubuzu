import 'dart:async';

import '../../domain/repositories/user_location_repository.dart';
import '../models/user_coordinates.dart';
import '../services/location_service.dart';

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
