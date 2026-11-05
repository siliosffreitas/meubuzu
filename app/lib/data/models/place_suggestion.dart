/// Tipos de sugestão exibidos na busca do mapa.
enum PlaceSuggestionType { line, stop }

/// Sugestão de linha ou parada retornada pela busca.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final PlaceSuggestionType type;
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;

  bool matches(String query) {
    return _normalize('$title $subtitle $id').contains(_normalize(query));
  }

  static String _normalize(String value) {
    var result = value.toLowerCase();
    const replacements = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    for (final entry in replacements.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }
}
