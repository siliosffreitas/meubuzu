import 'dart:math';

import 'user_coordinates.dart';

/// Parada de ônibus carregada do catálogo local.
class BusStop {
  const BusStop({
    required this.id,
    required this.code,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String code;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  /// Distância em metros até [position], calculada pela fórmula de Haversine.
  double distanceInMetersTo(UserCoordinates position) {
    const earthRadiusInMeters = 6371000.0;
    const degreesToRadians = pi / 180;

    final latitude1 = latitude * degreesToRadians;
    final latitude2 = position.latitude * degreesToRadians;
    final deltaLatitude = (position.latitude - latitude) * degreesToRadians;
    final deltaLongitude = (position.longitude - longitude) * degreesToRadians;

    final haversine =
        pow(sin(deltaLatitude / 2), 2) +
        cos(latitude1) * cos(latitude2) * pow(sin(deltaLongitude / 2), 2);
    final clamped = haversine.clamp(0.0, 1.0);
    final angularDistance = 2 * atan2(sqrt(clamped), sqrt(1 - clamped));

    return earthRadiusInMeters * angularDistance;
  }
}
