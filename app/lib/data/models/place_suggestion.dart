import '../utils/search_normalizer.dart';

/// Tipos de sugestão exibidos na busca do mapa.
enum PlaceSuggestionType { line, stop }

/// Sugestão de linha ou parada retornada pela busca.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.id,
    required this.code,
    required this.type,
    required this.title,
    required this.subtitle,
    this.latitude,
    this.longitude,
  });

  final String id;

  /// Código curto exibido em destaque (por exemplo, `sgLinha` da linha ou o
  /// código da parada).
  final String code;

  final PlaceSuggestionType type;

  /// Texto principal da sugestão (nome da linha ou da parada).
  final String title;

  /// Texto secundário (trajeto da linha ou endereço da parada).
  final String subtitle;

  /// Coordenadas da sugestão. Linhas ainda não possuem coordenadas no
  /// catálogo local, por isso podem ser nulas.
  final double? latitude;
  final double? longitude;

  bool matches(String query) {
    return normalizeSearchText('$code $title $subtitle $id')
        .contains(normalizeSearchText(query));
  }
}
