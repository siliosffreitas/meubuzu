import '../../../../../domain/repositories/auth_repository.dart';
import '../../../../../domain/contracts/contracts.dart';

/// Regras de apresentação da tela de confirmação do código.
class AuthCodeViewModel extends ViewmodelBase {
  AuthCodeViewModel(this._repository, {required this.email});

  final AuthRepository _repository;
  final String email;

  String _code = '';
  bool _isSubmitting = false;
  bool _isResending = false;
  String? _errorTitle;
  String? _errorMessage;

  String get code => _code;
  bool get isSubmitting => _isSubmitting;
  bool get isResending => _isResending;
  String? get errorTitle => _errorTitle;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _isSubmitting || _isResending;

  void setCode(String value) {
    _code = value;
    if (_errorMessage != null) {
      _clearError();
      notifyListeners();
    }
  }

  void _clearError() {
    _errorTitle = null;
    _errorMessage = null;
  }

  /// Confirma o código. Retorna `true` quando o acesso é liberado.
  Future<bool> confirm() async {
    if (isBusy) {
      return false;
    }

    if (_code.length != 6) {
      _errorTitle = null;
      _errorMessage = 'Informe os 6 dígitos do código.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _clearError();
    notifyListeners();

    try {
      await _repository.verifyEmailCode(email: email, code: _code);
      return true;
    } on InvalidCodeException {
      _errorTitle = 'Código inválido';
      _errorMessage =
          'Confira os 6 dígitos e tente novamente. Se precisar, solicite '
          'outro código.';
      return false;
    } catch (_) {
      _errorTitle = null;
      _errorMessage =
          'Não foi possível confirmar o código. Verifique sua conexão e tente '
          'novamente.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Reenvia o código. Retorna `true` quando o envio é concluído.
  Future<bool> resend() async {
    if (isBusy) {
      return false;
    }

    _isResending = true;
    _clearError();
    notifyListeners();

    try {
      await _repository.requestEmailCode(email);
      return true;
    } catch (_) {
      _errorTitle = null;
      _errorMessage =
          'Não foi possível reenviar o código. Verifique sua conexão e tente '
          'novamente.';
      return false;
    } finally {
      _isResending = false;
      notifyListeners();
    }
  }
}
