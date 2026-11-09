import 'package:meubuzu/domain/models/bus.dart';

/// Posição de um ônibus em determinado momento.
class BusPosition {
  const BusPosition({
    required this.bus,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    this.generatedAt,
  });

  final Bus bus;
  final double latitude;
  final double longitude;

  /// Momento em que a posição foi capturada.
  final DateTime capturedAt;

  /// Momento em que a posição foi gerada pelo veículo, quando informado.
  final DateTime? generatedAt;
}
