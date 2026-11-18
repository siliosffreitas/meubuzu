import '../../../../../../domain/models/favorite.dart';

/// Estados da aba de favoritos.
sealed class FavoritesState {
  const FavoritesState();

  /// Lista exibida quando o estado é [FavoritesReady].
  List<Favorite> get favorites => const [];
}

class FavoritesInitial extends FavoritesState {
  const FavoritesInitial();
}

class FavoritesLoading extends FavoritesState {
  const FavoritesLoading();
}

class FavoritesError extends FavoritesState {
  const FavoritesError(this.message);

  final String message;
}

class FavoritesReady extends FavoritesState {
  const FavoritesReady(this.items);

  final List<Favorite> items;

  @override
  List<Favorite> get favorites => items;
}
