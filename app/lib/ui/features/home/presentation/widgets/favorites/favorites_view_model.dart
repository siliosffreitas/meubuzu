import 'dart:async';

import '../../../../../../domain/contracts/contracts.dart';
import '../../../../../../domain/models/favorite.dart';
import '../../../../../../domain/repositories/auth_repository.dart';
import '../../../../../../domain/repositories/favorites_repository.dart';
import 'favorites_state.dart';

/// Carrega os favoritos da conta e exibe apenas os da cidade selecionada.
///
/// O repositório mantém os favoritos de todas as cidades; a cidade ativa vem
/// do [AuthRepository]. Quando a cidade muda, a lista exibida é recalculada
/// imediatamente, sem depender de uma nova busca ao backend.
class FavoritesViewModel extends ViewmodelBase {
  FavoritesViewModel(this._repository, this._auth) {
    _selectedCitySlug = _normalizedSlug(_auth.selectedCity?.slug);
    _subscription = _repository.favorites.listen(
      _handleFavorites,
      onError: (_) => _update(
        const FavoritesError('Não foi possível carregar os favoritos.'),
      ),
    );
    _auth.addListener(_handleCityChange);
  }

  final FavoritesRepository _repository;
  final AuthRepository _auth;
  StreamSubscription<List<Favorite>>? _subscription;

  List<Favorite> _allFavorites = const [];
  String? _selectedCitySlug;

  FavoritesState _state = const FavoritesInitial();
  String? _errorMessage;
  bool _isLoading = false;
  bool _isDisposed = false;

  FavoritesState get state => _state;

  /// Erro de uma ação de favoritar/desfavoritar, exibido como aviso na tela.
  String? get errorMessage => _errorMessage;

  /// Favoritos da cidade selecionada.
  List<Favorite> get favorites => _state.favorites;

  /// Favoritos agrupados pelo rótulo da cidade, na ordem recebida da API.
  Map<String, List<Favorite>> get groupedByCity {
    final groups = <String, List<Favorite>>{};
    for (final favorite in favorites) {
      final label = favorite.city.displayLabel;
      (groups[label] ??= <Favorite>[]).add(favorite);
    }
    return groups;
  }

  /// Consulta o endpoint sempre que a aba é exibida.
  Future<void> load() async {
    if (_isLoading || _isDisposed) {
      return;
    }
    // A cidade pode ter mudado enquanto a aba estava oculta.
    _syncSelectedCity();
    _isLoading = true;
    _update(const FavoritesLoading());

    try {
      await _repository.refresh();
    } catch (_) {
      _update(const FavoritesError('Não foi possível carregar os favoritos.'));
    } finally {
      _isLoading = false;
    }
  }

  Future<void> toggle(String boardingCode, {String? citySlug}) async {
    try {
      await _repository.toggle(boardingCode, citySlug: citySlug);
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'Não foi possível atualizar o favorito.';
    }
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }
    _errorMessage = null;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void _handleFavorites(List<Favorite> favorites) {
    _allFavorites = favorites;
    _emitVisibleFavorites();
  }

  void _handleCityChange() {
    _syncSelectedCity();
  }

  void _syncSelectedCity() {
    final nextSlug = _normalizedSlug(_auth.selectedCity?.slug);
    if (nextSlug == _selectedCitySlug) {
      return;
    }
    _selectedCitySlug = nextSlug;
    _emitVisibleFavorites();
  }

  void _emitVisibleFavorites() {
    final slug = _selectedCitySlug;
    final visible = slug == null
        ? _allFavorites
        : _allFavorites.where((favorite) => favorite.citySlug == slug).toList();
    _update(FavoritesReady(visible));
  }

  static String? _normalizedSlug(String? slug) {
    final value = slug?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  void _update(FavoritesState state) {
    if (_isDisposed) {
      return;
    }
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _subscription?.cancel();
    _auth.removeListener(_handleCityChange);
    super.dispose();
  }
}
