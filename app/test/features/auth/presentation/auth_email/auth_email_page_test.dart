import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/app.dart';
import 'package:meubuzu/features/auth/data/auth_repository.dart';
import 'package:meubuzu/features/auth/presentation/auth_email/auth_email_page.dart';

import '../../../../helpers/auth_test_helpers.dart';

void main() {
  group('tela de e-mail', () {
    testWidgets('mostra erro ao enviar sem e-mail', (tester) async {
      await tester.pumpWidget(
        appWith(const AuthEmailPage(repository: FakeAuthRepository())),
      );

      await tapVisible(tester, find.byType(FilledButton));

      expect(find.text('Informe seu e-mail para continuar.'), findsOneWidget);
    });

    testWidgets('mostra erro para e-mail inválido', (tester) async {
      await tester.pumpWidget(
        appWith(const AuthEmailPage(repository: FakeAuthRepository())),
      );

      await tester.enterText(find.byType(TextField), 'voce@exemplo');
      await tapVisible(tester, find.byType(FilledButton));

      expect(
        find.text('Digite um e-mail válido, como voce@exemplo.com.'),
        findsOneWidget,
      );
    });

    testWidgets('vai para a confirmação com e-mail válido', (tester) async {
      final repository = RecordingAuthRepository();

      await tester.pumpWidget(
        appWith(AuthEmailPage(repository: repository)),
      );

      await tester.enterText(find.byType(TextField), 'ana.lima@exemplo.com');
      await tapVisible(tester, find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(repository.emails, ['ana.lima@exemplo.com']);
      expect(find.text('Confira seu e-mail'), findsOneWidget);
      expect(find.text('ana.lima@exemplo.com'), findsOneWidget);
    });

    testWidgets('inicia na Home', (tester) async {
      await tester.pumpWidget(const MeuBuzuApp());
      await tester.pumpAndSettle();

      expect(find.text('Mapa'), findsOneWidget);
      expect(find.text('Favoritos'), findsOneWidget);
      expect(find.text('Conta'), findsOneWidget);
    });

    testWidgets('não estoura o layout em tela pequena', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: appWith(
            const AuthEmailPage(repository: FakeAuthRepository()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
