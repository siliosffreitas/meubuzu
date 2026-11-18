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
  bool isFavorite(String lineId) =>
      _favorites.any((favorite) => favorite.lineId == lineId);

  @override
  Future<void> refresh() => onRefresh?.call() ?? Future.value();

  @override
  Future<void> add(String lineId, {String? citySlug}) async {
    added.add(lineId);
    if (isFavorite(lineId)) {
      return;
    }
    _emit([
      ..._favorites,
      Favorite.fromJson({
        'id': 'favorite-$lineId',
        'lineId': lineId,
        'line': {
          'id': lineId,
          'name': 'LINHA $lineId',
          'origin': 'Origem',
          'destination': 'Destino',
          'boardingCode': lineId,
        },
        'city': {
          'slug': 'teresina',
          'name': 'Teresina',
          'label': 'Teresina - PI',
          'timezone': 'America/Fortaleza',
        },
      }),
    ]);
  }

  @override
  Future<void> remove(String lineId) async {
    removed.add(lineId);
    _emit(_favorites.where((item) => item.lineId != lineId).toList());
  }

  @override
  Future<void> toggle(String lineId, {String? citySlug}) =>
      isFavorite(lineId) ? remove(lineId) : add(lineId, citySlug: citySlug);

  void _emit(List<Favorite> favorites) {
    _favorites = List.unmodifiable(favorites);
    _controller.add(List.unmodifiable(_favorites));
  }

  @override
  void dispose() => _controller.close();
}
