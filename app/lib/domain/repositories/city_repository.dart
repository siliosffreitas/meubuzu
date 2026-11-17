import '../contracts/contracts.dart';
import '../models/city.dart';

/// Catálogo de cidades disponíveis para seleção.
abstract interface class CityRepository implements Repository {
  /// Cidades ativas, ordenadas pelo nome.
  Future<List<City>> fetchActiveCities();
}
