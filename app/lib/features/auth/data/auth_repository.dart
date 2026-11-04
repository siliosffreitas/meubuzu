/// Contrato de autenticação por e-mail com código temporário.
abstract interface class AuthRepository {
  /// Solicita o envio de um código de verificação para [email].
  Future<void> requestEmailCode(String email);
}

/// Implementação temporária usada enquanto o backend não está integrado.
///
/// Simula a latência da chamada HTTP e nunca expõe o código recebido.
class FakeAuthRepository implements AuthRepository {
  const FakeAuthRepository({
    this.latency = const Duration(milliseconds: 700),
  });

  final Duration latency;

  @override
  Future<void> requestEmailCode(String email) async {
    await Future<void>.delayed(latency);
  }
}
