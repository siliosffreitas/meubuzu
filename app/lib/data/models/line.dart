/// Linha de ônibus presente no catálogo local.
class Line {
  const Line({
    required this.id,
    required this.name,
    required this.origin,
    required this.destination,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String origin;
  final String destination;

  /// Coordenadas de referência da linha, quando o catálogo informa.
  final double? latitude;
  final double? longitude;
}
