import '../../data/models/place_suggestion.dart';
import '../contracts/contracts.dart';

/// Contrato de busca de linhas e paradas.
abstract interface class PlaceSearchRepository implements Repository {
  Future<List<PlaceSuggestion>> search(String query);
}
