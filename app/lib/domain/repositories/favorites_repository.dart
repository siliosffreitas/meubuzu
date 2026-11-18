import '../contracts/contracts.dart';
import '../models/favorite.dart';

/// Estado dos favoritos da conta, compartilhado entre as telas do app.
abstract interface class FavoritesRepository implements Repository {
  /// Emite a lista atual; novos ouvintes recebem o estado atual imediatamente.
  Stream<List<Favorite>> get favorites;

  List<Favorite> get snapshot;

  bool isFavorite(String lineId);

  /// Busca os favoritos no backend e substitui o estado local.
  Future<void> refresh();

  Future<void> add(String lineId, {String? citySlug});

  Future<void> remove(String lineId);

  /// Adiciona ou remove, alternando o estado atual da linha.
  Future<void> toggle(String lineId, {String? citySlug});
}
