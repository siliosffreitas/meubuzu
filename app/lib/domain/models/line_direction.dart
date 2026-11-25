/// Sentido/itinerário disponível para uma linha.
///
/// O [value] é o identificador usado pela API (`0`/`1`); o [label] é o texto
/// exibido ao usuário no seletor de sentido.
class LineDirection {
  const LineDirection({
    required this.value,
    required this.label,
    this.hasRoute = false,
    this.stopCount = 0,
  });

  final int value;
  final String label;

  /// Indica se o sentido possui traçado para desenhar no mapa.
  final bool hasRoute;

  /// Quantidade de paradas do itinerário, quando informada pelo backend.
  final int stopCount;

  factory LineDirection.fromJson(Map<String, dynamic> json) {
    return LineDirection(
      value: (json['value'] as num?)?.toInt() ?? 0,
      label: json['label']?.toString().trim() ?? '',
      hasRoute: json['hasRoute'] as bool? ?? false,
      stopCount: (json['stopCount'] as num?)?.toInt() ?? 0,
    );
  }
}
