import 'dart:async';

import '../../domain/models/favorite.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../services/favorites_service.dart';

/// Mantém o estado dos favoritos em memória e o sincroniza com o backend.
class FavoritesRepositoryImpl implements FavoritesRepository {
  FavoritesRepositoryImpl(this._service, this._auth);

  final FavoritesService _service;
  final AuthRepository _auth;

  final StreamController<List<Favorite>> _controller =
      StreamController<List<Favorite>>.broadcast();

  List<Favorite> _favorites = const [];
  bool _isDisposed = false;

  @override
  Stream<List<Favorite>> get favorites {
    return Stream<List<Favorite>>.multi((controller) {
      controller.add(List.unmodifiable(_favorites));
      final subscription = _controller.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  List<Favorite> get snapshot => List.unmodifiable(_favorites);

  @override
  bool isFavorite(String lineId) {
    final normalized = lineId.trim();
    return _favorites.any((favorite) => favorite.lineId == normalized);
  }

  @override
  Future<void> refresh() async {
    final favorites = await _service.fetch();
    _emit(favorites);
  }

  @override
  Future<void> add(String lineId, {String? citySlug}) async {
    final normalized = lineId.trim();
    if (normalized.isEmpty || isFavorite(normalized)) {
      return;
    }

    final slug = citySlug ?? _auth.selectedCity?.slug;
    if (slug == null || slug.trim().isEmpty) {
      throw StateError('É necessário escolher uma cidade para favoritar.');
    }

    final favorite = await _service.add(normalized, slug.trim());
    _emit([
      ..._favorites.where((item) => item.lineId != favorite.lineId),
      favorite,
    ]);
  }

  @override
  Future<void> remove(String lineId) async {
    final normalized = lineId.trim();
    if (normalized.isEmpty || !isFavorite(normalized)) {
      return;
    }
    await _service.remove(normalized);
    _emit(_favorites.where((item) => item.lineId != normalized).toList());
  }

  @override
  Future<void> toggle(String lineId, {String? citySlug}) async {
    if (isFavorite(lineId)) {
      await remove(lineId);
      return;
    }
    await add(lineId, citySlug: citySlug);
  }

  void _emit(List<Favorite> favorites) {
    if (_isDisposed) {
      return;
    }
    _favorites = favorites;
    _controller.add(List.unmodifiable(_favorites));
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller.close();
  }
}
