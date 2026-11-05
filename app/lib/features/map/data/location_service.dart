import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import 'user_coordinates.dart';

/// Estado da permissão de localização relevante para o app.
enum LocationPermissionStatus { granted, denied, deniedForever }

/// Contrato de acesso aos recursos de localização do dispositivo.
abstract interface class LocationService {
  /// Indica se o dispositivo possui hardware de GPS.
  Future<bool> hasGpsHardware();

  /// Indica se o serviço de localização (GPS) está ligado.
  Future<bool> isLocationServiceEnabled();

  Future<LocationPermissionStatus> checkPermission();

  Future<LocationPermissionStatus> requestPermission();

  /// Retorna a posição atual ou `null` caso não seja possível obtê-la.
  Future<UserCoordinates?> currentPosition();

  /// Abre as configurações de localização do sistema.
  Future<void> openLocationSettings();

  /// Abre as configurações do próprio app (usado quando a permissão é
  /// negada permanentemente).
  Future<void> openAppSettings();
}

/// Implementação baseada no `geolocator`.
class DeviceLocationService implements LocationService {
  const DeviceLocationService();

  static const _channel = MethodChannel('br.com.meubuzu.meubuzu/location');

  @override
  Future<bool> hasGpsHardware() async {
    if (kIsWeb) {
      return false;
    }
    // No iOS não existe uma API pública para detectar apenas o GPS. O
    // CoreLocation continua disponível mesmo em aparelhos sem GPS dedicado,
    // usando Wi-Fi para estimar a posição.
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final hasGps = await _channel.invokeMethod<bool>('hasGpsHardware');
      return hasGps ?? true;
    } on MissingPluginException {
      // Em testes e execuções sem o canal nativo registrado assumimos que o
      // dispositivo possui GPS.
      return true;
    } on PlatformException {
      return true;
    }
  }

  @override
  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<LocationPermissionStatus> checkPermission() async {
    return _mapPermission(await Geolocator.checkPermission());
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    return _mapPermission(await Geolocator.requestPermission());
  }

  @override
  Future<UserCoordinates?> currentPosition() async {
    // O provedor fundido do Google Play Services costuma ser mais preciso e
    // econômico. Em aparelhos sem Play Services (ou quando ele falha), usamos
    // o LocationManager nativo como alternativa.
    final fused = await _tryCurrentPosition(
      const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
    if (fused != null) {
      return fused;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final native = await _tryCurrentPosition(
        AndroidSettings(
          accuracy: LocationAccuracy.high,
          forceLocationManager: true,
          timeLimit: const Duration(seconds: 6),
        ),
      );
      if (native != null) {
        return native;
      }
    }

    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      return lastKnown == null ? null : _fromPosition(lastKnown);
    } catch (_) {
      return null;
    }
  }

  Future<UserCoordinates?> _tryCurrentPosition(
    LocationSettings settings,
  ) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      return _fromPosition(position);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Não foi possível obter a posição atual: $error');
      }
      return null;
    }
  }

  @override
  Future<void> openLocationSettings() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Geolocator.openLocationSettings();
      return;
    }
    await Geolocator.openAppSettings();
  }

  @override
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  static LocationPermissionStatus _mapPermission(
    LocationPermission permission,
  ) {
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => LocationPermissionStatus.granted,
      LocationPermission.deniedForever =>
        LocationPermissionStatus.deniedForever,
      _ => LocationPermissionStatus.denied,
    };
  }

  static UserCoordinates _fromPosition(Position position) {
    return UserCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}
