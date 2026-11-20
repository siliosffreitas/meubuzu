import '../contracts/contracts.dart';
import '../models/favorite.dart';

/// Estado dos favoritos da conta, compartilhado entre as telas do app.
abstract interface class FavoritesRepository implements Repository {
  /// Emite a lista atual; novos ouvintes recebem o estado atual imediatamente.
  Stream<List<Favorite>> get favorites;

  List<Favorite> get snapshot;

  /// Verifica o favorito pelo `boardingCode`, opcionalmente em uma cidade.
  bool isFavorite(String boardingCode, {String? citySlug});

  /// Busca os favoritos no backend e substitui o estado local.
  Future<void> refresh();

  /// Adiciona a linha [boardingCode] da cidade selecionada (ou [citySlug]).
  Future<void> add(String boardingCode, {String? citySlug});

  /// Remove o favorito da cidade do item, quando não informada [citySlug].
  Future<void> remove(String boardingCode, {String? citySlug});

  /// Adiciona ou remove, alternando o estado atual da linha.
  Future<void> toggle(String boardingCode, {String? citySlug});
}
