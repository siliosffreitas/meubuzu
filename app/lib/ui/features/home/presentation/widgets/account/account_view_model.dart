import '../../../../../../domain/contracts/contracts.dart';
import '../../../../../../domain/models/city.dart';
import '../../../../../../domain/repositories/auth_repository.dart';

/// Estado da aba Conta: identidade da sessão, cidade e encerramento.
class AccountViewModel extends ViewmodelBase {
  AccountViewModel(this._repository) {
    _repository.addListener(_onSessionChanged);
  }

  final AuthRepository _repository;

  bool _isLoggingOut = false;

  String? get email => _repository.currentUser?.email;

  String get accessLevel =>
      _repository.currentUser?.accessLevel ?? 'catalog_only';

  City? get selectedCity => _repository.selectedCity;

  String? get cityLabel => selectedCity?.label;

  String? get cityTimezone => selectedCity?.timezone;

  bool get isLoggingOut => _isLoggingOut;

  Future<void> logout() async {
    if (_isLoggingOut) {
      return;
    }

    _isLoggingOut = true;
    notifyListeners();

    try {
      await _repository.logout();
    } finally {
      _isLoggingOut = false;
      notifyListeners();
    }
  }

  void _onSessionChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _repository.removeListener(_onSessionChanged);
    super.dispose();
  }
}
