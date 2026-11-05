import 'package:flutter/foundation.dart';

import '../../../../data/repositories/auth_repository.dart';

/// Regras de apresentação da tela de entrada por e-mail.
class AuthEmailViewModel extends ChangeNotifier {
  AuthEmailViewModel(this._repository);

  final AuthRepository _repository;

  String _email = '';
  bool _isSubmitting = false;
  String? _errorMessage;

  String get email => _email;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  void setEmail(String value) {
    _email = value;
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Valida o e-mail e solicita o código. Retorna `true` em caso de sucesso.
  Future<bool> submit() async {
    if (_isSubmitting) {
      return false;
    }

    final validation = _validateEmail(_email);
    if (validation != null) {
      _errorMessage = validation;
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.requestEmailCode(_email.trim());
      return true;
    } catch (_) {
      _errorMessage =
          'Não foi possível enviar o código. Verifique sua conexão e tente '
          'novamente.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? _validateEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) {
      return 'Informe seu e-mail para continuar.';
    }
    if (!_emailPattern.hasMatch(email)) {
      return 'Digite um e-mail válido, como voce@exemplo.com.';
    }
    return null;
  }
}
