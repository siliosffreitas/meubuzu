import '../utils/search_normalizer.dart';

/// Tipos de sugestão exibidos na busca do mapa.
enum PlaceSuggestionType { line, stop }

/// Sugestão de linha ou parada retornada pela busca.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.latitude,
    this.longitude,
  });

  final String id;
  final PlaceSuggestionType type;
  final String title;
  final String subtitle;

  /// Coordenadas da sugestão. Linhas ainda não possuem coordenadas no
  /// catálogo local, por isso podem ser nulas.
  final double? latitude;
  final double? longitude;

  bool matches(String query) {
    return normalizeSearchText('$title $subtitle $id')
        .contains(normalizeSearchText(query));
  }
}
