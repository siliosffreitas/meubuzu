import 'package:meubuzu/domain/models/bus_position.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/domain/models/line_direction.dart';

import 'route.dart';

class TrackedLine {
  final Line line;
  final Route? route;
  final List<BusPosition> busPositions;

  /// Sentido selecionado para o traçado exibido no mapa.
  final int direction;

  /// Sentidos disponíveis informados pelo catálogo.
  final List<LineDirection> directions;

  new({
    required this.line,
    required this.route,
    required this.busPositions,
    this.direction = 0,
    this.directions = const [],
  });

  /// Sentido atual, quando o catálogo informou os rótulos disponíveis.
  LineDirection? get currentDirection {
    for (final direction in directions) {
      if (direction.value == this.direction) {
        return direction;
      }
    }
    return null;
  }
}
