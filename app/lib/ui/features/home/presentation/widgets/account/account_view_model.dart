import '../../../../../../domain/contracts/contracts.dart';
import '../../../../../../domain/repositories/auth_repository.dart';

/// Estado da aba Conta: identidade da sessão e encerramento.
class AccountViewModel extends ViewmodelBase {
  AccountViewModel(this._repository) {
    _repository.addListener(_onSessionChanged);
  }

  final AuthRepository _repository;

  bool _isLoggingOut = false;

  String? get email => _repository.currentUser?.email;

  String get accessLevel =>
      _repository.currentUser?.accessLevel ?? 'catalog_only';

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
