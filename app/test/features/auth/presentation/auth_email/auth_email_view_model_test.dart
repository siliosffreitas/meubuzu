import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/features/auth/presentation/auth_email/auth_email_view_model.dart';

import '../../../../helpers/auth_test_helpers.dart';

void main() {
  group('AuthEmailViewModel', () {
    test('começa vazio e sem erro', () {
      final viewModel = AuthEmailViewModel(RecordingAuthRepository());

      expect(viewModel.email, isEmpty);
      expect(viewModel.isSubmitting, isFalse);
      expect(viewModel.errorMessage, isNull);
    });

    test('guarda o e-mail digitado', () {
      final viewModel = AuthEmailViewModel(RecordingAuthRepository());

      viewModel.setEmail('ana.lima@exemplo.com');

      expect(viewModel.email, 'ana.lima@exemplo.com');
    });

    test('exige um e-mail antes de enviar', () async {
      final repository = RecordingAuthRepository();
      final viewModel = AuthEmailViewModel(repository);

      final submitted = await viewModel.submit();

      expect(submitted, isFalse);
      expect(viewModel.errorMessage, 'Informe seu e-mail para continuar.');
      expect(viewModel.isSubmitting, isFalse);
      expect(repository.emails, isEmpty);
    });

    test('rejeita e-mail inválido', () async {
      final repository = RecordingAuthRepository();
      final viewModel = AuthEmailViewModel(repository)
        ..setEmail('voce@exemplo');

      final submitted = await viewModel.submit();

      expect(submitted, isFalse);
      expect(
        viewModel.errorMessage,
        'Digite um e-mail válido, como voce@exemplo.com.',
      );
      expect(repository.emails, isEmpty);
    });

    test('remove espaços antes de enviar o e-mail', () async {
      final repository = RecordingAuthRepository();
      final viewModel = AuthEmailViewModel(repository)
        ..setEmail('  ana.lima@exemplo.com  ');

      final submitted = await viewModel.submit();

      expect(submitted, isTrue);
      expect(repository.emails, ['ana.lima@exemplo.com']);
      expect(viewModel.errorMessage, isNull);
    });

    test('limpa o erro quando o e-mail muda', () async {
      final viewModel = AuthEmailViewModel(RecordingAuthRepository());
      await viewModel.submit();
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      viewModel.setEmail('ana.lima@exemplo.com');

      expect(viewModel.errorMessage, isNull);
      expect(notifications, 1);
    });

    test('não notifica quando muda o e-mail sem erro pendente', () {
      final viewModel = AuthEmailViewModel(RecordingAuthRepository());
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      viewModel.setEmail('ana.lima@exemplo.com');

      expect(notifications, 0);
    });

    test('sinaliza envio em andamento e conclusão', () async {
      final repository = RecordingAuthRepository()
        ..requestGate = Completer<void>();
      final viewModel = AuthEmailViewModel(repository)
        ..setEmail('ana.lima@exemplo.com');
      final states = <bool>[];
      viewModel.addListener(() => states.add(viewModel.isSubmitting));

      final sending = viewModel.submit();

      expect(viewModel.isSubmitting, isTrue);
      expect(states, [true]);

      repository.requestGate!.complete();
      expect(await sending, isTrue);

      expect(viewModel.isSubmitting, isFalse);
      expect(states, [true, false]);
    });

    test('ignora envio enquanto outro está em andamento', () async {
      final repository = RecordingAuthRepository()
        ..requestGate = Completer<void>();
      final viewModel = AuthEmailViewModel(repository)
        ..setEmail('ana.lima@exemplo.com');

      final first = viewModel.submit();
      final second = await viewModel.submit();

      expect(second, isFalse);

      repository.requestGate!.complete();
      expect(await first, isTrue);
      expect(repository.emails, ['ana.lima@exemplo.com']);
    });

    test('mostra erro de conexão quando o envio falha', () async {
      final repository = RecordingAuthRepository(failRequest: true);
      final viewModel = AuthEmailViewModel(repository)
        ..setEmail('ana.lima@exemplo.com');

      final submitted = await viewModel.submit();

      expect(submitted, isFalse);
      expect(
        viewModel.errorMessage,
        'Não foi possível enviar o código. Verifique sua conexão e tente '
        'novamente.',
      );
      expect(viewModel.isSubmitting, isFalse);
    });
  });
}
