import 'package:meubuzu/domain/models/bus_position.dart';
import 'package:meubuzu/domain/models/line.dart';

import 'route.dart';

class TrackedLine {
  final Line line;
  final Route? route;
  final List<BusPosition> busPositions;

  new({required this.line, required this.route, required this.busPositions});
}
