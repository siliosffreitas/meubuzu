import 'dart:async';

import '../../../../../../data/models/place_suggestion.dart';
import '../../../../../../domain/models/line.dart';
import '../../../../../../domain/models/tracked_line.dart';
import '../../../../../../domain/models/favorite.dart';
import '../../../../../../domain/repositories/favorites_repository.dart';
import '../../../../../../domain/repositories/place_search_repository.dart';
import '../../../../../../domain/repositories/tracking_repository.dart';
import '../../../../../../domain/contracts/contracts.dart';
import 'map_search_cache.dart';

/// Estado da busca exibida sobre o mapa.
///
/// Além dos resultados da busca, mantém quais linhas já estão sendo
/// acompanhadas no mapa, consultando o [TrackingRepository].
class MapSearchViewModel extends ViewmodelBase {
  /// Inatividade necessária antes de consultar o backend.
  ///
  /// Cada nova tecla cancela a busca pendente, de modo que só uma pausa maior
  /// que este intervalo dispara a requisição.
  static const Duration searchDebounce = Duration(seconds: 1);

  factory MapSearchViewModel(
    PlaceSearchRepository repository, {
    TrackingRepository? trackingRepository,
    FavoritesRepository? favoritesRepository,
    MapSearchCache? cache,
  }) {
    return MapSearchViewModel._(
      repository,
      trackingRepository,
      favoritesRepository,
      cache,
    );
  }

  MapSearchViewModel._(
    this._repository,
    this._trackingRepository,
    this._favoritesRepository,
    this._cache,
  ) {
    _query = _cache?.query ?? '';
    _results = _cache?.results ?? const [];
    _trackingSubscription = _trackingRepository?.trackingRoutes.listen(
      _handleTrackedLines,
      onError: _handleTrackingError,
    );
    _favoritesSubscription = _favoritesRepository?.favorites.listen(
      _handleFavorites,
      onError: _handleFavoritesError,
    );
    // A busca pode abrir antes da aba Favoritos: carrega a lista da conta para
    // que as estrelas já reflitam os favoritos salvos no backend.
    unawaited(_favoritesRepository?.refresh().catchError((Object _) {}));
  }

  final PlaceSearchRepository _repository;
  final TrackingRepository? _trackingRepository;
  final FavoritesRepository? _favoritesRepository;
  final MapSearchCache? _cache;
  StreamSubscription<List<TrackedLine>>? _trackingSubscription;
  StreamSubscription<List<Favorite>>? _favoritesSubscription;

  Timer? _debounce;
  int _searchId = 0;

  String _query = '';
  bool _isFocused = false;
  bool _isLoading = false;
  List<PlaceSuggestion> _results = const [];
  Set<String> _trackedLineCodes = const {};
  Set<String> _favoriteLineCodes = const {};

  String get query => _query;
  bool get isFocused => _isFocused;
  bool get isLoading => _isLoading;
  List<PlaceSuggestion> get results => _results;
  bool get hasQuery => _query.trim().isNotEmpty;

  /// Códigos (`sgLinha`) das linhas já acompanhadas no mapa.
  Set<String> get trackedLineCodes => _trackedLineCodes;

  /// Indica se a linha [code] (`sgLinha`) já está sendo acompanhada.
  bool isLineTracked(String code) => _trackedLineCodes.contains(code.trim());

  /// A estrela aparece apenas quando há um repositório de favoritos disponível.
  bool get hasFavorites => _favoritesRepository != null;

  /// Códigos (`boardingCode`) das linhas favoritas da conta.
  Set<String> get favoriteLineCodes => _favoriteLineCodes;

  /// Alterna o favorito da linha [boardingCode].
  Future<void> toggleFavorite(String boardingCode) async {
    await _favoritesRepository?.toggle(boardingCode);
  }

  /// A lista de sugestões aparece apenas enquanto o campo está em uso.
  bool get showsResults => _isFocused && hasQuery;

  void setFocused(bool value) {
    if (_isFocused == value) {
      return;
    }
    _isFocused = value;
    notifyListeners();
  }

  void setQuery(String value) {
    _query = value;
    _debounce?.cancel();

    if (value.trim().isEmpty) {
      _searchId++;
      _isLoading = false;
      _results = const [];
      _cache?.clear();
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    final requestId = ++_searchId;
    _debounce = Timer(searchDebounce, () async {
      List<PlaceSuggestion> results;
      try {
        results = await _repository.search(value);
      } catch (_) {
        results = const [];
      }
      if (requestId != _searchId) {
        return;
      }
      _results = results;
      _isLoading = false;
      _cache?.save(_query, results);
      notifyListeners();
    });
  }

  void clear() {
    setQuery('');
  }

  void _handleTrackedLines(List<TrackedLine> trackedLines) {
    _trackedLineCodes = {
      for (final code
          in trackedLines.map((tracked) => _searchCode(tracked.line)))
        if (code.isNotEmpty) code,
    };
    notifyListeners();
  }

  /// Código usado na busca e no rastreamento: o `sgLinha` da linha.
  String _searchCode(Line line) => line.publicCode;

  void _handleTrackingError(Object error, StackTrace stackTrace) {
    _trackedLineCodes = const {};
    notifyListeners();
  }

  void _handleFavorites(List<Favorite> favorites) {
    _favoriteLineCodes = {for (final favorite in favorites) favorite.displayCode};
    notifyListeners();
  }

  void _handleFavoritesError(Object error, StackTrace stackTrace) {
    _favoriteLineCodes = const {};
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _trackingSubscription?.cancel();
    _favoritesSubscription?.cancel();
    super.dispose();
  }
}
