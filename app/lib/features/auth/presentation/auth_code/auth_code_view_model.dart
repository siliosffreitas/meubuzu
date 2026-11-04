import 'package:flutter/foundation.dart';

import '../../data/auth_repository.dart';

/// Regras de apresentação da tela de confirmação do código.
class AuthCodeViewModel extends ChangeNotifier {
  AuthCodeViewModel(this._repository, {required this.email});

  final AuthRepository _repository;
  final String email;

  String _code = '';
  bool _isSubmitting = false;
  bool _isResending = false;
  String? _errorMessage;

  String get code => _code;
  bool get isSubmitting => _isSubmitting;
  bool get isResending => _isResending;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _isSubmitting || _isResending;

  void setCode(String value) {
    _code = value;
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Confirma o código. Retorna `true` quando o acesso é liberado.
  Future<bool> confirm() async {
    if (isBusy) {
      return false;
    }

    if (_code.length != 6) {
      _errorMessage = 'Informe os 6 dígitos do código.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.verifyEmailCode(email: email, code: _code);
      return true;
    } on InvalidCodeException {
      _errorMessage = 'Código incorreto ou expirado. Confira e tente novamente.';
      return false;
    } catch (_) {
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
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.requestEmailCode(email);
      return true;
    } catch (_) {
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
