import '../contracts/contracts.dart';

/// Contrato de autenticação por e-mail com código temporário.
abstract interface class AuthRepository implements Repository {
  /// Solicita o envio de um código de verificação para [email].
  ///
  /// Também é usado quando o usuário pede para reenviar o código.
  Future<void> requestEmailCode(String email);

  /// Confirma o código recebido. Lança [InvalidCodeException] quando o código
  /// está incorreto, expirado ou já foi utilizado.
  Future<void> verifyEmailCode({required String email, required String code});
}

/// Erro lançado quando o código informado não é aceito.
class InvalidCodeException implements Exception {
  const InvalidCodeException();
}
