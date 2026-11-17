import 'package:meubuzu/domain/models/bus.dart';

/// Posição de um ônibus em determinado momento.
class BusPosition {
  const BusPosition({
    required this.bus,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    this.lineCode = '',
    this.generatedAt,
    this.receivedAt,
    this.speed,
    this.heading,
    this.previousLatitude,
    this.previousLongitude,
    this.isStale = false,
    this.dataMode,
    this.source,
  });

  final Bus bus;
  final double latitude;
  final double longitude;

  /// `sgLinha` da linha a que a posição pertence, com zeros à esquerda.
  final String lineCode;

  /// Momento em que a posição foi capturada.
  final DateTime capturedAt;

  /// Momento em que a posição foi gerada pelo veículo, quando informado.
  final DateTime? generatedAt;

  /// Momento em que o backend recebeu a posição.
  final DateTime? receivedAt;

  final double? speed;

  /// Rumo calculado pelo backend, em graus (0 = norte, 90 = leste).
  ///
  /// O app apenas usa este valor para girar a seta; quando é `null`, não há
  /// direção conhecida e a seta não é exibida.
  final double? heading;

  /// Coordenada imediatamente anterior do mesmo veículo, quando houver.
  final double? previousLatitude;
  final double? previousLongitude;

  /// Indica se a captura é antiga o suficiente para ser sinalizada ao usuário.
  final bool isStale;

  /// `demo` ou `live`, usado apenas para avisos de interface.
  final String? dataMode;

  /// Identificador da fonte no backend; o app não toma decisões por ele.
  final String? source;
}
