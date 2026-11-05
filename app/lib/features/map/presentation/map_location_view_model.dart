import 'package:flutter/foundation.dart';

import '../data/location_service.dart';

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

/// Verifica GPS, permissão e posição do usuário, nessa ordem.
class MapLocationViewModel extends ChangeNotifier {
  MapLocationViewModel(this._service);

  final LocationService _service;

  MapLocationStatus _status = MapLocationStatus.idle;
  UserCoordinates? _position;
  bool _isInitializing = false;

  MapLocationStatus get status => _status;
  UserCoordinates? get position => _position;
  bool get isReady => _status == MapLocationStatus.ready;

  /// Executa a sequência: hardware de GPS → serviço ligado → permissão →
  /// posição atual.
  ///
  /// Use [requestPermission] como `false` para apenas revalidar o estado ao
  /// voltar das configurações, sem abrir o diálogo de permissão novamente.
  Future<void> initialize({bool requestPermission = true}) async {
    if (_isInitializing) {
      return;
    }
    _isInitializing = true;
    _position = null;
    _update(MapLocationStatus.checking);

    try {
      final hasGps = await _service.hasGpsHardware();
      if (!hasGps) {
        _update(MapLocationStatus.noGpsHardware);
        return;
      }

      final serviceEnabled = await _service.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _update(MapLocationStatus.serviceDisabled);
        return;
      }

      var permission = await _service.checkPermission();
      if (permission == LocationPermissionStatus.denied && requestPermission) {
        permission = await _service.requestPermission();
      }
      if (permission != LocationPermissionStatus.granted) {
        _update(
          permission == LocationPermissionStatus.deniedForever
              ? MapLocationStatus.permissionDeniedForever
              : MapLocationStatus.permissionDenied,
        );
        return;
      }

      final position = await _service.currentPosition();
      if (position == null) {
        _update(MapLocationStatus.unavailable);
        return;
      }

      _position = position;
      _update(MapLocationStatus.ready);
    } catch (_) {
      _update(MapLocationStatus.unavailable);
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> openLocationSettings() => _service.openLocationSettings();

  Future<void> openAppSettings() => _service.openAppSettings();

  void _update(MapLocationStatus status) {
    _status = status;
    notifyListeners();
  }
}
