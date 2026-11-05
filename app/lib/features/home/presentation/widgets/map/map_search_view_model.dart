import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../../data/repositories/place_search_repository.dart';

/// Estado da busca exibida sobre o mapa.
class MapSearchViewModel extends ChangeNotifier {
  MapSearchViewModel(this._repository);

  final PlaceSearchRepository _repository;

  Timer? _debounce;
  int _searchId = 0;

  String _query = '';
  bool _isFocused = false;
  bool _isLoading = false;
  List<PlaceSuggestion> _results = const [];

  String get query => _query;
  bool get isFocused => _isFocused;
  bool get isLoading => _isLoading;
  List<PlaceSuggestion> get results => _results;
  bool get hasQuery => _query.trim().isNotEmpty;

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
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    final requestId = ++_searchId;
    _debounce = Timer(const Duration(milliseconds: 320), () async {
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
      notifyListeners();
    });
  }

  void clear() {
    setQuery('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
