import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/features/auth/data/auth_repository.dart';

void main() {
  group('FakeAuthRepository', () {
    const repository = FakeAuthRepository(latency: Duration.zero);

    test('envia o código sem erro', () async {
      await expectLater(
        repository.requestEmailCode('ana.lima@exemplo.com'),
        completes,
      );
    });

    test('aceita códigos diferentes do reservado', () async {
      await expectLater(
        repository.verifyEmailCode(
          email: 'ana.lima@exemplo.com',
          code: '654321',
        ),
        completes,
      );
    });

    test('recusa o código 123456 do protótipo', () async {
      await expectLater(
        repository.verifyEmailCode(
          email: 'ana.lima@exemplo.com',
          code: FakeAuthRepository.prototypeInvalidCode,
        ),
        throwsA(isA<InvalidCodeException>()),
      );
    });
  });
}
