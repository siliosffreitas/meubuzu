import '../utils/search_normalizer.dart';

/// Tipos de sugestão exibidos na busca do mapa.
enum PlaceSuggestionType { line, stop }

/// Sugestão de linha ou parada retornada pela busca.
///
/// O `code` é o identificador público: `boardingCode` (`sgLinha`) para linhas
/// e `code` para paradas.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.code,
    required this.type,
    required this.title,
    required this.subtitle,
    this.latitude,
    this.longitude,
  });

  /// Código curto exibido em destaque e usado na navegação.
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
    return normalizeSearchText('$code $title $subtitle')
        .contains(normalizeSearchText(query));
  }
}
