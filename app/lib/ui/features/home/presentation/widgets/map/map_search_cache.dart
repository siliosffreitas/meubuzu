import '../../../../../../data/models/place_suggestion.dart';
import '../../../../../../domain/contracts/contracts.dart';

/// Guarda a última busca concluída para restaurar a tela ao reabri-la.
///
/// O texto e os resultados são salvos juntos para evitar exibir uma consulta
/// que não corresponde à lista mostrada.
class MapSearchCache implements Service {
  String _query = '';
  List<PlaceSuggestion> _results = const [];

  /// Texto da última busca concluída.
  String get query => _query;

  /// Resultados da última busca concluída.
  List<PlaceSuggestion> get results => _results;

  /// Salva a consulta e os resultados correspondentes.
  void save(String query, List<PlaceSuggestion> results) {
    _query = query;
    _results = List.unmodifiable(results);
  }

  /// Limpa a busca guardada.
  void clear() {
    _query = '';
    _results = const [];
  }
}
