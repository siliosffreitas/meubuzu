import '../../domain/repositories/auth_repository.dart';

/// Implementação temporária usada enquanto o backend não está integrado.
///
/// Simula a latência da chamada HTTP e nunca expõe o código recebido.
/// Enquanto o backend não existe, o código [prototypeInvalidCode] sempre é
/// recusado para permitir exercitar o estado de erro do protótipo.
class FakeAuthRepository implements AuthRepository {
  const FakeAuthRepository({this.latency = const Duration(milliseconds: 700)});

  /// Código reservado para simular um código inválido no protótipo.
  static const prototypeInvalidCode = '123456';

  final Duration latency;

  @override
  Future<void> requestEmailCode(String email) async {
    await Future<void>.delayed(latency);
  }

  @override
  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    await Future<void>.delayed(latency);
    if (code == prototypeInvalidCode) {
      throw const InvalidCodeException();
    }
  }

  @override
  void dispose() {}
}
