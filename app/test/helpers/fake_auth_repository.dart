import 'package:flutter/foundation.dart';
import 'package:meubuzu/domain/models/auth_user.dart';
import 'package:meubuzu/domain/repositories/auth_repository.dart';

/// Repositório de autenticação em memória para testes de UI.
///
/// Não usa rede nem armazenamento; registra as chamadas recebidas.
class FakeAuthRepository extends ChangeNotifier implements AuthRepository {
  FakeAuthRepository({
    this.latency = Duration.zero,
    this.rejectCode = false,
    this.invalidCode = 'invalid_code',
    this.rateLimited,
    AuthUser? user,
  }) {
    _user = user;
  }

  /// Espera antes de responder, para exercitar estados de carregamento.
  final Duration latency;

  /// Quando `true`, [verifyEmailCode] lança [InvalidCodeException].
  final bool rejectCode;

  /// Código estável usado no [InvalidCodeException].
  final String invalidCode;

  /// Quando definido, as chamadas de envio lançam o limite informado.
  final RateLimitedException? rateLimited;

  final emails = <String>[];
  final verifiedEmails = <String>[];
  final confirmed = <String>[];
  int restoreCalls = 0;
  int validateCalls = 0;
  int logoutCalls = 0;

  AuthUser? _user;

  @override
  AuthUser? get currentUser => _user;

  @override
  bool get isAuthenticated => _user != null;

  Future<void> _wait() async {
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
  }

  @override
  Future<void> requestEmailCode(String email) async {
    await _wait();
    final limit = rateLimited;
    if (limit != null) {
      throw limit;
    }
    emails.add(email);
  }

  @override
  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    await _wait();
    if (rejectCode) {
      throw InvalidCodeException(invalidCode);
    }
    verifiedEmails.add(email);
    confirmed.add(code);
    _user = AuthUser(id: 'user-1', email: email);
    notifyListeners();
  }

  @override
  Future<void> restoreSession() async {
    restoreCalls++;
  }

  @override
  Future<void> validateSession() async {
    validateCalls++;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    _user = null;
    notifyListeners();
  }
}
