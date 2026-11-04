import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/core/theme/app_theme.dart';
import 'package:meubuzu/features/auth/data/auth_repository.dart';

/// Repositório que registra as chamadas recebidas durante o teste.
class RecordingAuthRepository implements AuthRepository {
  RecordingAuthRepository({this.rejectCode = false});

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

/// Envolve [home] no app mínimo usado pelos testes de widget.
Widget appWith(Widget home) {
  return MaterialApp(theme: AppTheme.light(), home: home);
}

/// Garante que o alvo esteja visível antes de tocar.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}
