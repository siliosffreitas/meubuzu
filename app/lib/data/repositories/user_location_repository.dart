import 'dart:async';

import '../../domain/repositories/user_location_repository.dart';
import '../../domain/models/bus_stop.dart';
import '../../domain/models/user_coordinates.dart';
import '../services/bus_stop_service.dart';
import '../services/location_service.dart';

/// Implementação baseada na localização do dispositivo.
class DeviceUserLocationRepository implements UserLocationRepository {
  DeviceUserLocationRepository(this._service, this._busStopService);

  final LocationService _service;
  final BusStopService _busStopService;
  final _positions = StreamController<UserCoordinates>.broadcast();
  final _nearbyStops = StreamController<List<BusStop>>.broadcast();

  UserCoordinates? _latestPosition;
  List<BusStop>? _latestNearbyStops;
  bool _isRefreshing = false;
  bool _isDisposed = false;
  int _nearbyStopsRequest = 0;

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
  Stream<List<BusStop>> get nearbyStops {
    return Stream<List<BusStop>>.multi((controller) {
      final latest = _latestNearbyStops;
      if (latest != null) {
        controller.add(latest);
      }
      final subscription = _nearbyStops.stream.listen(
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
      unawaited(_updateNearbyStops(position));
    } catch (_) {
      _publishFailure(UserLocationFailure.unavailable);
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _updateNearbyStops(UserCoordinates position) async {
    final request = ++_nearbyStopsRequest;
    try {
      final stops = await _busStopService.findNearby(position);
      if (_isDisposed || request != _nearbyStopsRequest) {
        return;
      }
      _latestNearbyStops = stops;
      _nearbyStops.add(stops);
    } catch (error, stackTrace) {
      if (_isDisposed || request != _nearbyStopsRequest) {
        return;
      }
      _nearbyStops.addError(error, stackTrace);
    }
  }

  @override
  Future<void> openLocationSettings() => _service.openLocationSettings();

  @override
  Future<void> openAppSettings() => _service.openAppSettings();

  @override
  void dispose() {
    _isDisposed = true;
    _nearbyStopsRequest++;
    _positions.close();
    _nearbyStops.close();
  }

  void _publishFailure(UserLocationFailure failure) {
    _positions.addError(UserLocationException(failure));
  }
}
