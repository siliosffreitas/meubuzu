import '../contracts/contracts.dart';
import '../models/bus_stop.dart';
import '../models/line.dart';

abstract interface class DetailsBusStopRepository implements Repository {
  Stream<BusStop?> get currentBusStop;
  Stream<List<Line?>> get lines;

  Future<void> setCurrentBusStop(String busStopCode);
}
