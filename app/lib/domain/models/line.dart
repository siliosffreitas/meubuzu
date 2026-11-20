/// Linha de ônibus presente no catálogo da cidade selecionada.
///
/// A identidade pública da linha é o `boardingCode` (`sgLinha`): o código que o
/// passageiro conhece e que aparece em todas as rotas da API.
class Line {
  const Line({
    required this.name,
    required this.origin,
    required this.destination,
    required this.boardingCode,
    this.latitude,
    this.longitude,
  });

  final String name;
  final String origin;
  final String destination;

  /// Código de embarque (`sgLinha`), obrigatório e único na cidade.
  final String boardingCode;

  /// Coordenadas de referência da linha, quando o catálogo informa.
  final double? latitude;
  final double? longitude;

  /// Lê uma linha no formato devolvido pela API do catálogo.
  factory Line.fromJson(Map<String, dynamic> json) {
    return Line(
      name: json['name']?.toString() ?? '',
      origin: json['origin']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      boardingCode: json['boardingCode']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  /// Código público sem espaços, usado em parâmetros e chaves de rastreamento.
  String get publicCode => boardingCode.trim();
}
