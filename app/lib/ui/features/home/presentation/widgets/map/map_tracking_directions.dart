import 'dart:math';

import '../../../../../../domain/models/bus_position.dart';
import '../../../../../../domain/models/tracked_line.dart';
import 'map_tracking_polylines.dart';

/// Identificador estável de um ônibus dentro da linha acompanhada.
String trackedBusKey(TrackedLine tracked, BusPosition position) =>
    '${trackedLineKey(tracked)}:${position.bus.code}';

/// Rumo inicial de [from] para [to] em graus (0 = norte, 90 = leste).
double bearingBetween(BusPosition from, BusPosition to) {
  const degreesToRadians = pi / 180;
  const radiansToDegrees = 180 / pi;

  final latitude1 = from.latitude * degreesToRadians;
  final latitude2 = to.latitude * degreesToRadians;
  final deltaLongitude = (to.longitude - from.longitude) * degreesToRadians;

  final y = sin(deltaLongitude) * cos(latitude2);
  final x =
      cos(latitude1) * sin(latitude2) -
      sin(latitude1) * cos(latitude2) * cos(deltaLongitude);

  return (atan2(y, x) * radiansToDegrees + 360) % 360;
}

/// Guarda a última posição de cada ônibus e calcula a direção do movimento.
///
/// A primeira captura de um ônibus não tem direção conhecida; a seta só passa
/// a existir depois de ele se deslocar em relação à captura anterior.
class TrackingBusDirections {
  final Map<String, BusPosition> _lastPositions = <String, BusPosition>{};
  final Map<String, double> _bearings = <String, double>{};

  /// Direção atual de cada ônibus, por [trackedBusKey].
  Map<String, double> get bearings =>
      Map<String, double>.unmodifiable(_bearings);

  /// Atualiza as direções com as posições de [trackedLines].
  ///
  /// Posições repetidas mantêm a direção anterior e ônibus que saíram do
  /// rastreamento são descartados.
  void update(List<TrackedLine> trackedLines) {
    final currentKeys = <String>{};

    for (final tracked in trackedLines) {
      for (final position in tracked.busPositions) {
        final key = trackedBusKey(tracked, position);
        currentKeys.add(key);

        final previous = _lastPositions[key];
        if (previous != null &&
            (previous.latitude != position.latitude ||
                previous.longitude != position.longitude)) {
          _bearings[key] = bearingBetween(previous, position);
        }

        _lastPositions[key] = position;
      }
    }

    _lastPositions.removeWhere((key, _) => !currentKeys.contains(key));
    _bearings.removeWhere((key, _) => !currentKeys.contains(key));
  }
}
