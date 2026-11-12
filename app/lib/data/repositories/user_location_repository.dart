import 'dart:async';
import 'dart:math' as math;

import '../../domain/repositories/user_location_repository.dart';
import '../../domain/models/bus_stop.dart';
import '../../domain/models/user_coordinates.dart';
import '../services/bus_stop_service.dart';
import '../services/location_service.dart';

/// Área visível normalizada, usada para evitar consultas repetidas.
typedef _VisibleArea = ({double south, double north, double west, double east});

/// Implementação baseada na localização do dispositivo.
class DeviceUserLocationRepository implements UserLocationRepository {
  DeviceUserLocationRepository(this._service, this._busStopService);

  final LocationService _service;
  final BusStopService _busStopService;
  final _positions = StreamController<UserCoordinates>.broadcast();
  final _visibleStops = StreamController<List<BusStop>>.broadcast();

  UserCoordinates? _latestPosition;
  List<BusStop>? _latestVisibleStops;
  _VisibleArea? _lastVisibleArea;
  bool _isRefreshing = false;
  bool _isDisposed = false;
  int _visibleStopsRequest = 0;

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
  Stream<List<BusStop>> get visibleStops {
    return Stream<List<BusStop>>.multi((controller) {
      final latest = _latestVisibleStops;
      if (latest != null) {
        controller.add(latest);
      }
      final subscription = _visibleStops.stream.listen(
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
  Future<void> updateVisibleArea({
    required UserCoordinates southwest,
    required UserCoordinates northeast,
  }) async {
    if (_isDisposed) {
      return;
    }

    final area = (
      south: math.min(southwest.latitude, northeast.latitude),
      north: math.max(southwest.latitude, northeast.latitude),
      west: math.min(southwest.longitude, northeast.longitude),
      east: math.max(southwest.longitude, northeast.longitude),
    );
    if (_lastVisibleArea == area) {
      return;
    }
    _lastVisibleArea = area;

    final request = ++_visibleStopsRequest;
    try {
      final stops = await _busStopService.findWithinBounds(
        UserCoordinates(latitude: area.south, longitude: area.west),
        UserCoordinates(latitude: area.north, longitude: area.east),
      );
      if (_isDisposed || request != _visibleStopsRequest) {
        return;
      }
      _latestVisibleStops = stops;
      _visibleStops.add(stops);
    } catch (error, stackTrace) {
      if (_isDisposed || request != _visibleStopsRequest) {
        return;
      }
      _visibleStops.addError(error, stackTrace);
    }
  }

  @override
  void clearVisibleStops() {
    if (_isDisposed) {
      return;
    }
    _lastVisibleArea = null;
    _visibleStopsRequest++;
    if (_latestVisibleStops?.isEmpty ?? false) {
      return;
    }
    _latestVisibleStops = const [];
    _visibleStops.add(const []);
  }

  @override
  Future<void> openLocationSettings() => _service.openLocationSettings();

  @override
  Future<void> openAppSettings() => _service.openAppSettings();

  @override
  void dispose() {
    _isDisposed = true;
    _visibleStopsRequest++;
    _positions.close();
    _visibleStops.close();
  }

  void _publishFailure(UserLocationFailure failure) {
    _positions.addError(UserLocationException(failure));
  }
}
