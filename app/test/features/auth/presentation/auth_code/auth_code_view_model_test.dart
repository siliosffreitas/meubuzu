import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/features/auth/presentation/auth_code/auth_code_view_model.dart';

import '../../../../helpers/auth_test_helpers.dart';

void main() {
  group('AuthCodeViewModel', () {
    test('começa vazio e sem erro', () {
      final viewModel = AuthCodeViewModel(
        RecordingAuthRepository(),
        email: 'ana.lima@exemplo.com',
      );

      expect(viewModel.email, 'ana.lima@exemplo.com');
      expect(viewModel.code, isEmpty);
      expect(viewModel.isSubmitting, isFalse);
      expect(viewModel.isResending, isFalse);
      expect(viewModel.isBusy, isFalse);
      expect(viewModel.errorMessage, isNull);
    });

    test('guarda o código digitado', () {
      final viewModel = AuthCodeViewModel(
        RecordingAuthRepository(),
        email: 'ana.lima@exemplo.com',
      );

      viewModel.setCode('123456');

      expect(viewModel.code, '123456');
    });

    test('exige os 6 dígitos antes de confirmar', () async {
      final repository = RecordingAuthRepository();
      final viewModel = AuthCodeViewModel(
        repository,
        email: 'ana.lima@exemplo.com',
      )..setCode('123');

      final confirmed = await viewModel.confirm();

      expect(confirmed, isFalse);
      expect(viewModel.errorTitle, isNull);
      expect(viewModel.errorMessage, 'Informe os 6 dígitos do código.');
      expect(repository.confirmed, isEmpty);
    });

    test('confirma enviando e-mail e código', () async {
      final repository = RecordingAuthRepository();
      final viewModel = AuthCodeViewModel(
        repository,
        email: 'ana.lima@exemplo.com',
      )..setCode('123456');

      final confirmed = await viewModel.confirm();

      expect(confirmed, isTrue);
      expect(repository.verifiedEmails, ['ana.lima@exemplo.com']);
      expect(repository.confirmed, ['123456']);
      expect(viewModel.errorMessage, isNull);
    });

    test('sinaliza confirmação em andamento e conclusão', () async {
      final repository = RecordingAuthRepository()
        ..verifyGate = Completer<void>();
      final viewModel = AuthCodeViewModel(
        repository,
        email: 'ana.lima@exemplo.com',
      )..setCode('123456');
      final states = <bool>[];
      viewModel.addListener(() => states.add(viewModel.isBusy));

      final confirming = viewModel.confirm();

      expect(viewModel.isSubmitting, isTrue);
      expect(viewModel.isBusy, isTrue);
      expect(states, [true]);

      repository.verifyGate!.complete();
      expect(await confirming, isTrue);

      expect(viewModel.isSubmitting, isFalse);
      expect(viewModel.isBusy, isFalse);
      expect(states, [true, false]);
    });

    test('ignora confirmação enquanto outra está em andamento', () async {
      final repository = RecordingAuthRepository()
        ..verifyGate = Completer<void>();
      final viewModel = AuthCodeViewModel(
        repository,
        email: 'ana.lima@exemplo.com',
      )..setCode('123456');

      final first = viewModel.confirm();
      final second = await viewModel.confirm();

      expect(second, isFalse);

      repository.verifyGate!.complete();
      expect(await first, isTrue);
      expect(repository.confirmed, ['123456']);
    });

    test('mostra erro para código recusado', () async {
      final repository = RecordingAuthRepository(rejectCode: true);
      final viewModel = AuthCodeViewModel(
        repository,
        email: 'ana.lima@exemplo.com',
      )..setCode('000000');

      final confirmed = await viewModel.confirm();

      expect(confirmed, isFalse);
      expect(viewModel.errorTitle, 'Código inválido');
      expect(
        viewModel.errorMessage,
        'Confira os 6 dígitos e tente novamente. Se precisar, solicite '
        'outro código.',
      );
      expect(viewModel.isSubmitting, isFalse);
    });

    test('mostra erro de conexão quando a confirmação falha', () async {
      final repository = RecordingAuthRepository(failVerify: true);
      final viewModel = AuthCodeViewModel(
        repository,
        email: 'ana.lima@exemplo.com',
      )..setCode('123456');

      final confirmed = await viewModel.confirm();

      expect(confirmed, isFalse);
      expect(viewModel.errorTitle, isNull);
      expect(
        viewModel.errorMessage,
        'Não foi possível confirmar o código. Verifique sua conexão e tente '
        'novamente.',
      );
    });

    test('reenvia o código para o e-mail informado', () async {
      final repository = RecordingAuthRepository();
      final viewModel = AuthCodeViewModel(
        repository,
        email: 'ana.lima@exemplo.com',
      );

      final sent = await viewModel.resend();

      expect(sent, isTrue);
      expect(repository.emails, ['ana.lima@exemplo.com']);
      expect(viewModel.errorMessage, isNull);
    });

    test('sinaliza reenvio em andamento e conclusão', () async {
      final repository = RecordingAuthRepository()
        ..requestGate = Completer<void>();
      final viewModel = AuthCodeViewModel(
        repository,
        email: 'ana.lima@exemplo.com',
      );
      final states = <bool>[];
      viewModel.addListener(() => states.add(viewModel.isResending));

      final resending = viewModel.resend();

      expect(viewModel.isResending, isTrue);
      expect(viewModel.isBusy, isTrue);

      repository.requestGate!.complete();
      expect(await resending, isTrue);

      expect(viewModel.isResending, isFalse);
      expect(viewModel.isBusy, isFalse);
      expect(states, [true, false]);
    });

    test('ignora reenvio durante uma confirmação', () async {
      final repository = RecordingAuthRepository()
        ..verifyGate = Completer<void>();
      final viewModel = AuthCodeViewModel(
        repository,
        email: 'ana.lima@exemplo.com',
      )..setCode('123456');

      final confirming = viewModel.confirm();
      final resent = await viewModel.resend();

      expect(resent, isFalse);
      expect(repository.emails, isEmpty);

      repository.verifyGate!.complete();
      expect(await confirming, isTrue);
    });

    test('mostra erro de conexão quando o reenvio falha', () async {
      final repository = RecordingAuthRepository(failRequest: true);
      final viewModel = AuthCodeViewModel(
        repository,
        email: 'ana.lima@exemplo.com',
      );

      final sent = await viewModel.resend();

      expect(sent, isFalse);
      expect(
        viewModel.errorMessage,
        'Não foi possível reenviar o código. Verifique sua conexão e tente '
        'novamente.',
      );
    });

    test('limpa o erro quando o código muda', () async {
      final viewModel = AuthCodeViewModel(
        RecordingAuthRepository(),
        email: 'ana.lima@exemplo.com',
      );
      await viewModel.confirm();
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      viewModel.setCode('1');

      expect(viewModel.errorTitle, isNull);
      expect(viewModel.errorMessage, isNull);
      expect(notifications, 1);
    });

    test('não notifica quando muda o código sem erro pendente', () {
      final viewModel = AuthCodeViewModel(
        RecordingAuthRepository(),
        email: 'ana.lima@exemplo.com',
      );
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      viewModel.setCode('1');

      expect(notifications, 0);
    });
  });
}
