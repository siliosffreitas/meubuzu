import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/features/auth/presentation/auth_code/auth_code_page.dart';

import '../../../../helpers/auth_test_helpers.dart';

void main() {
  group('tela de código', () {
    testWidgets('exige os 6 dígitos', (tester) async {
      await tester.pumpWidget(
        appWith(
          AuthCodePage(
            email: 'ana.lima@exemplo.com',
            repository: RecordingAuthRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Confirmar código'),
      );

      expect(find.text('Informe os 6 dígitos do código.'), findsOneWidget);
    });

    testWidgets('confirma o código digitado', (tester) async {
      final repository = RecordingAuthRepository();

      await tester.pumpWidget(
        appWith(
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

      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Confirmar código'),
      );
      await tester.pumpAndSettle();

      expect(repository.confirmed, ['123456']);
      expect(find.text('Código confirmado.'), findsOneWidget);
    });

    testWidgets('mostra erro para código recusado', (tester) async {
      await tester.pumpWidget(
        appWith(
          AuthCodePage(
            email: 'ana.lima@exemplo.com',
            repository: RecordingAuthRepository(rejectCode: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '000000');
      await tapVisible(
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
          child: appWith(
            AuthCodePage(
              email: 'ana.lima@exemplo.com',
              repository: RecordingAuthRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
