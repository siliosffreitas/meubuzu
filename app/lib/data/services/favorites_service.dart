import '../../domain/contracts/contracts.dart';
import '../../domain/models/favorite.dart';

/// Acesso aos favoritos da conta no backend.
abstract interface class FavoritesService implements Service {
  Future<List<Favorite>> fetch();

  /// Adiciona a linha [lineId] do catálogo da cidade [citySlug].
  Future<Favorite> add(String lineId, String citySlug);

  Future<void> remove(String lineId);
}
