import 'dart:async';

import '../../../../../../domain/contracts/contracts.dart';
import '../../../../../../domain/models/favorite.dart';
import '../../../../../../domain/repositories/favorites_repository.dart';
import 'favorites_state.dart';

/// Carrega os favoritos da conta e mantém a lista agrupada por cidade.
class FavoritesViewModel extends ViewmodelBase {
  FavoritesViewModel(this._repository) {
    _subscription = _repository.favorites.listen(
      (favorites) => _update(FavoritesReady(favorites)),
      onError: (_) => _update(
        const FavoritesError('Não foi possível carregar os favoritos.'),
      ),
    );
  }

  final FavoritesRepository _repository;
  StreamSubscription<List<Favorite>>? _subscription;

  FavoritesState _state = const FavoritesInitial();
  String? _errorMessage;
  bool _isLoading = false;
  bool _isDisposed = false;

  FavoritesState get state => _state;

  /// Erro de uma ação de favoritar/desfavoritar, exibido como aviso na tela.
  String? get errorMessage => _errorMessage;

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

  Future<void> toggle(String lineId) async {
    try {
      await _repository.toggle(lineId);
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
    super.dispose();
  }
}
