import 'package:meubuzu/domain/models/line.dart';

import '../contracts/contracts.dart';
import '../models/bus_stop.dart';

abstract interface class DetailsLineRepository implements Repository {
  Stream<Line?> get currentLine;
  Stream<BusStop?> get busStops;

  Future<void> setCurrentLine(Line line);

}