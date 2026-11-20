import 'dart:async';

import 'package:meubuzu/domain/models/favorite.dart';
import 'package:meubuzu/domain/repositories/favorites_repository.dart';

/// Favoritos em memória para testes de UI e view models.
class FakeFavoritesRepository implements FavoritesRepository {
  FakeFavoritesRepository([List<Favorite> initial = const []]) {
    _favorites = List.unmodifiable(initial);
  }

  final StreamController<List<Favorite>> _controller =
      StreamController<List<Favorite>>.broadcast();

  late List<Favorite> _favorites;
  Future<void> Function()? onRefresh;
  final added = <String>[];
  final removed = <String>[];

  @override
  Stream<List<Favorite>> get favorites {
    return Stream<List<Favorite>>.multi((controller) {
      controller.add(List.unmodifiable(_favorites));
      final subscription = _controller.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  List<Favorite> get snapshot => List.unmodifiable(_favorites);

  @override
  bool isFavorite(String boardingCode, {String? citySlug}) => _favorites.any(
    (favorite) =>
        favorite.displayCode == boardingCode.trim() &&
        (citySlug == null || favorite.citySlug == citySlug),
  );

  @override
  Future<void> refresh() => onRefresh?.call() ?? Future.value();

  @override
  Future<void> add(String boardingCode, {String? citySlug}) async {
    added.add(boardingCode);
    if (isFavorite(boardingCode, citySlug: citySlug)) {
      return;
    }
    _emit([
      ..._favorites,
      Favorite.fromJson({
        'boardingCode': boardingCode,
        'line': {
          'name': 'LINHA $boardingCode',
          'origin': 'Origem',
          'destination': 'Destino',
          'boardingCode': boardingCode,
        },
        'city': {
          'slug': citySlug ?? 'teresina',
          'name': 'Teresina',
          'label': 'Teresina - PI',
          'timezone': 'America/Fortaleza',
        },
      }),
    ]);
  }

  @override
  Future<void> remove(String boardingCode, {String? citySlug}) async {
    removed.add(boardingCode);
    _emit(
      _favorites
          .where(
            (item) =>
                !(item.displayCode == boardingCode.trim() &&
                    (citySlug == null || item.citySlug == citySlug)),
          )
          .toList(),
    );
  }

  @override
  Future<void> toggle(String boardingCode, {String? citySlug}) =>
      isFavorite(boardingCode, citySlug: citySlug)
          ? remove(boardingCode, citySlug: citySlug)
          : add(boardingCode, citySlug: citySlug);

  void _emit(List<Favorite> favorites) {
    _favorites = List.unmodifiable(favorites);
    _controller.add(List.unmodifiable(_favorites));
  }

  @override
  void dispose() => _controller.close();
}
