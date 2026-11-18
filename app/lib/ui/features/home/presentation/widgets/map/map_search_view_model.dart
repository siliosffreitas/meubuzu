import 'dart:async';

import '../../../../../../data/models/place_suggestion.dart';
import '../../../../../../domain/models/line.dart';
import '../../../../../../domain/models/tracked_line.dart';
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
    MapSearchCache? cache,
  }) {
    return MapSearchViewModel._(repository, trackingRepository, cache);
  }

  MapSearchViewModel._(
    this._repository,
    this._trackingRepository,
    this._cache,
  ) {
    _query = _cache?.query ?? '';
    _results = _cache?.results ?? const [];
    _trackingSubscription = _trackingRepository?.trackingRoutes.listen(
      _handleTrackedLines,
      onError: _handleTrackingError,
    );
  }

  final PlaceSearchRepository _repository;
  final TrackingRepository? _trackingRepository;
  final MapSearchCache? _cache;
  StreamSubscription<List<TrackedLine>>? _trackingSubscription;

  Timer? _debounce;
  int _searchId = 0;

  String _query = '';
  bool _isFocused = false;
  bool _isLoading = false;
  List<PlaceSuggestion> _results = const [];
  Set<String> _trackedLineCodes = const {};

  String get query => _query;
  bool get isFocused => _isFocused;
  bool get isLoading => _isLoading;
  List<PlaceSuggestion> get results => _results;
  bool get hasQuery => _query.trim().isNotEmpty;

  /// Códigos (`sgLinha`) das linhas já acompanhadas no mapa.
  Set<String> get trackedLineCodes => _trackedLineCodes;

  /// Indica se a linha [code] (`sgLinha`) já está sendo acompanhada.
  bool isLineTracked(String code) => _trackedLineCodes.contains(code.trim());

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
      for (final tracked in trackedLines) _searchCode(tracked.line),
    };
    notifyListeners();
  }

  /// Código usado na busca (`sgLinha`), com fallback para o código interno.
  ///
  /// O rastreamento é iniciado pelo `sgLinha` (o `code` da sugestão), enquanto
  /// [Line.id] guarda o `codigoLinha` do catálogo. Comparar apenas o `id`
  /// deixaria de reconhecer a linha acompanhada.
  String _searchCode(Line line) {
    final boardingCode = line.boardingCode?.trim();
    return boardingCode != null && boardingCode.isNotEmpty
        ? boardingCode
        : line.id.trim();
  }

  void _handleTrackingError(Object error, StackTrace stackTrace) {
    _trackedLineCodes = const {};
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _trackingSubscription?.cancel();
    super.dispose();
  }
}
