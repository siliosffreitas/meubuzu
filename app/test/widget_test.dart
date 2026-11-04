import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/app.dart';
import 'package:meubuzu/core/theme/app_theme.dart';
import 'package:meubuzu/features/auth/data/auth_repository.dart';
import 'package:meubuzu/features/auth/presentation/auth_email_page.dart';

class _RecordingAuthRepository implements AuthRepository {
  final emails = <String>[];

  @override
  Future<void> requestEmailCode(String email) async {
    emails.add(email);
  }
}

Future<void> _tapSubmit(WidgetTester tester) async {
  final button = find.byType(FilledButton);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pump();
}

void main() {
  testWidgets('mostra erro ao enviar sem e-mail', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AuthEmailPage(repository: FakeAuthRepository())),
    );

    await _tapSubmit(tester);

    expect(find.text('Informe seu e-mail para continuar.'), findsOneWidget);
  });

  testWidgets('mostra erro para e-mail inválido', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AuthEmailPage(repository: FakeAuthRepository())),
    );

    await tester.enterText(find.byType(TextField), 'voce@exemplo');
    await _tapSubmit(tester);

    expect(
      find.text('Digite um e-mail válido, como voce@exemplo.com.'),
      findsOneWidget,
    );
  });

  testWidgets('solicita o código com e-mail válido', (tester) async {
    final repository = _RecordingAuthRepository();

    await tester.pumpWidget(
      MaterialApp(home: AuthEmailPage(repository: repository)),
    );

    await tester.enterText(find.byType(TextField), 'voce@exemplo.com');
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(repository.emails, ['voce@exemplo.com']);
    expect(find.text('Verifique seu e-mail'), findsOneWidget);
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
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AuthEmailPage(repository: FakeAuthRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
