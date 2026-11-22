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

  String? get _selectedCitySlug {
    final slug = _auth.selectedCity?.slug.trim();
    return slug == null || slug.isEmpty ? null : slug;
  }

  Favorite? _findFavorite(String boardingCode, {String? citySlug}) {
    final code = boardingCode.trim();
    final slug = citySlug?.trim();
    for (final favorite in _favorites) {
      if (favorite.displayCode.trim() != code) {
        continue;
      }
      if (slug != null && favorite.citySlug != slug) {
        continue;
      }
      return favorite;
    }
    return null;
  }

  @override
  bool isFavorite(String boardingCode, {String? citySlug}) {
    final favorite = _findFavorite(boardingCode, citySlug: citySlug);
    if (favorite != null) {
      return true;
    }
    // Sem cidade informada, considera apenas a cidade selecionada para não
    // confundir códigos iguais em cidades diferentes.
    final selectedSlug = _selectedCitySlug;
    return selectedSlug == null
        ? false
        : _findFavorite(boardingCode, citySlug: selectedSlug) != null;
  }

  @override
  Future<List<Favorite>> getFavoritesForCity(String? citySlug) async {
    final all = await _service.fetch();
    if (citySlug == null) {
      return all;
    }
    return all.where((f) => f.city.slug.trim() == citySlug).toList();
  }

  @override
  Future<void> refresh() async {
    final favorites = await _service.fetch();
    _emit(_sorted(favorites));
  }

  @override
  Future<void> add(String boardingCode, {String? citySlug}) async {
    final code = boardingCode.trim();
    if (code.isEmpty || isFavorite(code, citySlug: citySlug)) {
      return;
    }

    final slug = (citySlug ?? _selectedCitySlug)?.trim();
    if (slug == null || slug.isEmpty) {
      throw StateError('É necessário escolher uma cidade para favoritar.');
    }

    final favorite = await _service.add(code, slug);
    _emit(
      _sorted([
        ..._favorites.where(
          (item) =>
              !(item.citySlug == favorite.citySlug &&
                  item.displayCode == favorite.displayCode),
        ),
        favorite,
      ]),
    );
  }

  @override
  Future<void> remove(String boardingCode, {String? citySlug}) async {
    final code = boardingCode.trim();
    if (code.isEmpty) {
      return;
    }
    final favorite = _findFavorite(code, citySlug: citySlug);
    if (favorite == null) {
      return;
    }
    await _service.remove(favorite.citySlug, code);
    _emit(
      _favorites
          .where(
            (item) =>
                !(item.citySlug == favorite.citySlug &&
                    item.displayCode == code),
          )
          .toList(),
    );
  }

  @override
  Future<void> toggle(String boardingCode, {String? citySlug}) async {
    if (isFavorite(boardingCode, citySlug: citySlug)) {
      await remove(boardingCode, citySlug: citySlug);
      return;
    }
    await add(boardingCode, citySlug: citySlug);
  }

  static List<Favorite> _sorted(List<Favorite> favorites) {
    final list = List<Favorite>.from(favorites);
    list.sort(_compareFavorites);
    return list;
  }

  static int _compareFavorites(Favorite a, Favorite b) {
    final city = a.city.name.compareTo(b.city.name);
    if (city != 0) {
      return city;
    }
    final citySlug = a.city.slug.compareTo(b.city.slug);
    if (citySlug != 0) {
      return citySlug;
    }

    final aCode = a.displayCode;
    final bCode = b.displayCode;
    final aBlank = aCode.isEmpty ? 1 : 0;
    final bBlank = bCode.isEmpty ? 1 : 0;
    if (aBlank != bBlank) {
      return aBlank.compareTo(bBlank);
    }

    final aNum = int.tryParse(aCode);
    final bNum = int.tryParse(bCode);
    if (aNum != null && bNum != null && aNum != bNum) {
      return aNum.compareTo(bNum);
    }
    if (aNum != null && bNum == null) {
      return -1;
    }
    if (aNum == null && bNum != null) {
      return 1;
    }

    return a.line.name.compareTo(b.line.name);
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
