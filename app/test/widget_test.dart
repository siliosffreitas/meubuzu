import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/app.dart';
import 'package:meubuzu/core/theme/app_theme.dart';
import 'package:meubuzu/features/auth/data/auth_repository.dart';
import 'package:meubuzu/features/auth/presentation/auth_code_page.dart';
import 'package:meubuzu/features/auth/presentation/auth_email_page.dart';

class _RecordingAuthRepository implements AuthRepository {
  _RecordingAuthRepository({this.rejectCode = false});

  final bool rejectCode;
  final emails = <String>[];
  final confirmed = <String>[];

  @override
  Future<void> requestEmailCode(String email) async {
    emails.add(email);
  }

  @override
  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    if (rejectCode) {
      throw const InvalidCodeException();
    }
    confirmed.add(code);
  }
}

Widget _appWith(Widget home) {
  return MaterialApp(theme: AppTheme.light(), home: home);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  group('tela de e-mail', () {
    testWidgets('mostra erro ao enviar sem e-mail', (tester) async {
      await tester.pumpWidget(
        _appWith(const AuthEmailPage(repository: FakeAuthRepository())),
      );

      await _tapVisible(tester, find.byType(FilledButton));

      expect(find.text('Informe seu e-mail para continuar.'), findsOneWidget);
    });

    testWidgets('mostra erro para e-mail inválido', (tester) async {
      await tester.pumpWidget(
        _appWith(const AuthEmailPage(repository: FakeAuthRepository())),
      );

      await tester.enterText(find.byType(TextField), 'voce@exemplo');
      await _tapVisible(tester, find.byType(FilledButton));

      expect(
        find.text('Digite um e-mail válido, como voce@exemplo.com.'),
        findsOneWidget,
      );
    });

    testWidgets('vai para a confirmação com e-mail válido', (tester) async {
      final repository = _RecordingAuthRepository();

      await tester.pumpWidget(
        _appWith(AuthEmailPage(repository: repository)),
      );

      await tester.enterText(find.byType(TextField), 'ana.lima@exemplo.com');
      await _tapVisible(tester, find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(repository.emails, ['ana.lima@exemplo.com']);
      expect(find.text('Confira seu e-mail'), findsOneWidget);
      expect(find.text('ana.lima@exemplo.com'), findsOneWidget);
    });

    testWidgets('inicia na tela de e-mail', (tester) async {
      await tester.pumpWidget(const MeuBuzuApp());
      await tester.pumpAndSettle();

      expect(find.text('Menos espera.\nMais caminho.'), findsOneWidget);
    });

    testWidgets('não estoura o layout em tela pequena', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: _appWith(
            const AuthEmailPage(repository: FakeAuthRepository()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('tela de código', () {
    testWidgets('exige os 6 dígitos', (tester) async {
      await tester.pumpWidget(
        _appWith(
          AuthCodePage(
            email: 'ana.lima@exemplo.com',
            repository: _RecordingAuthRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Confirmar código'),
      );

      expect(find.text('Informe os 6 dígitos do código.'), findsOneWidget);
    });

    testWidgets('confirma o código digitado', (tester) async {
      final repository = _RecordingAuthRepository();

      await tester.pumpWidget(
        _appWith(
          AuthCodePage(
            email: 'ana.lima@exemplo.com',
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);

      await _tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Confirmar código'),
      );
      await tester.pumpAndSettle();

      expect(repository.confirmed, ['123456']);
      expect(find.text('Código confirmado.'), findsOneWidget);
    });

    testWidgets('mostra erro para código recusado', (tester) async {
      await tester.pumpWidget(
        _appWith(
          AuthCodePage(
            email: 'ana.lima@exemplo.com',
            repository: _RecordingAuthRepository(rejectCode: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '000000');
      await _tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Confirmar código'),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Código incorreto ou expirado. Confira e tente novamente.'),
        findsOneWidget,
      );
    });

    testWidgets('não estoura o layout em tela pequena', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: _appWith(
            AuthCodePage(
              email: 'ana.lima@exemplo.com',
              repository: _RecordingAuthRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
