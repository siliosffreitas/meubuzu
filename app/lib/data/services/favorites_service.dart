import '../../domain/contracts/contracts.dart';
import '../../domain/models/favorite.dart';

/// Acesso aos favoritos da conta no backend.
abstract interface class FavoritesService implements Service {
  Future<List<Favorite>> fetch();

  /// Adiciona a linha [boardingCode] do catálogo da cidade [citySlug].
  Future<Favorite> add(String boardingCode, String citySlug);

  /// Remove o favorito identificado por cidade e código de embarque.
  Future<void> remove(String citySlug, String boardingCode);
}
