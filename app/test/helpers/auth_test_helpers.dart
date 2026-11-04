import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/core/theme/app_theme.dart';
import 'package:meubuzu/features/auth/data/auth_repository.dart';

/// Repositório que registra as chamadas recebidas durante o teste.
///
/// Use [rejectCode] para simular código inválido, [failRequest]/[failVerify]
/// para simular falha de conexão e [requestGate]/[verifyGate] para controlar
/// quando cada chamada termina.
class RecordingAuthRepository implements AuthRepository {
  RecordingAuthRepository({
    this.rejectCode = false,
    this.failRequest = false,
    this.failVerify = false,
  });

  final bool rejectCode;
  final bool failRequest;
  final bool failVerify;

  /// Quando definido, [requestEmailCode] espera o gate ser completado.
  Completer<void>? requestGate;

  /// Quando definido, [verifyEmailCode] espera o gate ser completado.
  Completer<void>? verifyGate;

  final emails = <String>[];
  final confirmed = <String>[];
  final verifiedEmails = <String>[];

  @override
  Future<void> requestEmailCode(String email) async {
    await requestGate?.future;
    if (failRequest) {
      throw Exception('falha de conexão');
    }
    emails.add(email);
  }

  @override
  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    await verifyGate?.future;
    if (failVerify) {
      throw Exception('falha de conexão');
    }
    if (rejectCode) {
      throw const InvalidCodeException();
    }
    verifiedEmails.add(email);
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
