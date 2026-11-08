/// Linha de ônibus presente no catálogo local.
class Line {
  const Line({
    required this.id,
    required this.name,
    required this.origin,
    required this.destination,
    required this.boardingCode,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String origin;
  final String destination;

  /// Código de embarque (`sgLinha`) usado na busca, quando informado.
  final String? boardingCode;

  /// Coordenadas de referência da linha, quando o catálogo informa.
  final double? latitude;
  final double? longitude;
}
