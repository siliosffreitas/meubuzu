import '../../../../domain/contracts/contracts.dart';
import '../../../../domain/models/city.dart';
import '../../../../domain/repositories/auth_repository.dart';
import '../../../../domain/repositories/city_repository.dart';

/// Estado da tela de seleção de cidade.
class SelectCityViewModel extends ViewmodelBase {
  SelectCityViewModel(this._cities, this._auth, {this.isChangeMode = false});

  final CityRepository _cities;
  final AuthRepository _auth;

  /// `true` quando a tela foi aberta pela aba Conta para trocar a cidade.
  final bool isChangeMode;

  List<City> _availableCities = const [];
  City? _selection;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<City> get cities => _availableCities;
  City? get selectedCity => _selection ?? _auth.selectedCity;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  bool get canSubmit => selectedCity != null && !_isLoading && !_isSubmitting;

  /// Carrega as cidades ativas e pré-seleciona a cidade atual.
  Future<void> load() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final cities = await _cities.fetchActiveCities();
      _availableCities = cities;

      final current = _auth.selectedCity;
      if (current != null && cities.any((city) => city.slug == current.slug)) {
        _selection = cities.firstWhere((city) => city.slug == current.slug);
      } else if (cities.length == 1) {
        _selection = cities.first;
      }

      if (cities.isEmpty) {
        _errorMessage = 'Nenhuma cidade disponível no momento.';
      }
    } catch (_) {
      _errorMessage =
          'Não foi possível carregar as cidades. Verifique sua conexão e '
          'tente novamente.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void choose(City city) {
    if (_isSubmitting) {
      return;
    }
    _selection = city;
    _errorMessage = null;
    notifyListeners();
  }

  /// Salva a cidade escolhida. Retorna `true` quando pode seguir para a Home.
  Future<bool> confirm() async {
    final city = selectedCity;
    if (city == null) {
      _errorMessage = 'Escolha uma cidade para continuar.';
      notifyListeners();
      return false;
    }

    if (!isChangeMode && _auth.selectedCity?.slug == city.slug) {
      return true;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _auth.selectCity(city);
      return true;
    } on CityUnavailableException {
      _errorMessage = 'Esta cidade não está disponível. Escolha outra.';
      return false;
    } catch (_) {
      _errorMessage = 'Não foi possível salvar a cidade. Tente novamente.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
