import 'package:flutter/foundation.dart';

import '../contracts/contracts.dart';
import '../models/auth_user.dart';

/// Contrato de autenticação por e-mail com código temporário.
///
/// O repositório é a fonte de verdade da sessão: persiste os tokens no
/// armazenamento seguro e notifica quando o usuário entra ou sai.
abstract interface class AuthRepository implements Repository, Listenable {
  /// Conta autenticada, ou `null` quando não há sessão.
  AuthUser? get currentUser;

  bool get isAuthenticated;

  /// Solicita o envio de um código de verificação para [email].
  ///
  /// Também é usado quando o usuário pede para reenviar o código.
  Future<void> requestEmailCode(String email);

  /// Confirma o código, persiste a sessão e notifica os ouvintes.
  ///
  /// Lança [InvalidCodeException] quando o código está incorreto, expirado ou
  /// já foi utilizado.
  Future<void> verifyEmailCode({required String email, required String code});

  /// Carrega a sessão salva no dispositivo, sem chamar a API.
  Future<void> restoreSession();

  /// Valida a sessão salva em segundo plano e tenta renová-la quando expirada.
  Future<void> validateSession();

  /// Encerra a sessão local e revoga o refresh token no backend quando possível.
  Future<void> logout();
}

/// Erro lançado quando o código informado não é aceito.
class InvalidCodeException implements Exception {
  const InvalidCodeException([this.code = 'invalid_code']);

  /// Código estável devolvido pela API (`invalid_code`, `code_expired`...).
  final String code;
}

/// Erro lançado quando a API limita a quantidade de tentativas.
class RateLimitedException implements Exception {
  const RateLimitedException({required this.code, this.retryAfter});

  /// `rate_limited` ou `too_many_attempts`.
  final String code;

  /// Tempo sugerido de espera, quando informado pela API.
  final Duration? retryAfter;
}
