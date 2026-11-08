import 'package:meubuzu/domain/models/bus.dart';

class BusPosition {
  final Bus bus;
  final double latitude;
  final double longitude;

  new({required this.bus, required this.latitude, required this.longitude});
}