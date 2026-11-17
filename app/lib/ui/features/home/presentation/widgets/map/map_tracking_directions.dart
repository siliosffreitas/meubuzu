import '../../../../../../domain/models/bus_position.dart';
import '../../../../../../domain/models/tracked_line.dart';
import 'map_tracking_polylines.dart';

/// Identificador estável de um ônibus dentro da linha acompanhada.
String trackedBusKey(TrackedLine tracked, BusPosition position) =>
    '${trackedLineKey(tracked)}:${position.bus.code}';

/// Expõe o rumo calculado pelo backend para cada ônibus, por [trackedBusKey].
///
/// O app não calcula a direção: o backend compara a posição atual com a
/// anterior e envia `heading` em graus. Quando o valor não vem, a seta não é
/// exibida. O mapa é reconstruído a cada atualização, então não há histórico
/// local que precise ser limpo.
class TrackingBusDirections {
  final Map<String, double> _bearings = <String, double>{};

  /// Direção atual de cada ônibus, por [trackedBusKey].
  Map<String, double> get bearings =>
      Map<String, double>.unmodifiable(_bearings);

  /// Atualiza as direções com o `heading` recebido do backend.
  void update(List<TrackedLine> trackedLines) {
    _bearings.clear();

    for (final tracked in trackedLines) {
      for (final position in tracked.busPositions) {
        final heading = position.heading;
        if (heading == null) {
          continue;
        }
        _bearings[trackedBusKey(tracked, position)] = heading % 360;
      }
    }
  }
}
