import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meubuzu/domain/models/auth_user.dart';
import 'package:meubuzu/domain/repositories/auth_repository.dart';
import 'package:meubuzu/ui/core/theme/app_theme.dart';
import 'package:meubuzu/ui/features/auth/presentation/auth_code/auth_code_page.dart';
import 'package:meubuzu/ui/routing/app_routes.dart';

import 'fake_auth_repository.dart';

/// Repositório que registra as chamadas recebidas durante o teste.
///
/// Use [rejectCode] para simular código inválido, [failRequest]/[failVerify]
/// para simular falha de conexão e [requestGate]/[verifyGate] para controlar
/// quando cada chamada termina.
class RecordingAuthRepository extends ChangeNotifier implements AuthRepository {
  RecordingAuthRepository({
    this.rejectCode = false,
    this.failRequest = false,
    this.failVerify = false,
    AuthUser? user,
  }) {
    _user = user;
  }

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

  AuthUser? _user;
  int restoreCalls = 0;
  int validateCalls = 0;
  int logoutCalls = 0;

  @override
  AuthUser? get currentUser => _user;

  @override
  bool get isAuthenticated => _user != null;

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
    _user = AuthUser(id: 'user-1', email: email);
    notifyListeners();
  }

  @override
  Future<void> restoreSession() async {
    restoreCalls++;
  }

  @override
  Future<void> validateSession() async {
    validateCalls++;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    _user = null;
    notifyListeners();
  }
}

/// Envolve [home] no app mínimo usado pelos testes de widget.
///
/// Usa GoRouter com a Home em `/` e a confirmação de código em `/auth/code`.
Widget appWith(Widget home) {
  return appWithRoutes(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        builder: (context, state) => home,
      ),
      GoRoute(
        path: AppRoutes.authCode,
        name: AppRoutes.authCodeName,
        builder: (context, state) => AuthCodePage(
          email: state.extra! as String,
          repository: FakeAuthRepository(),
        ),
      ),
    ],
  );
}

/// Envolve [routes] em um app com GoRouter para testar navegação.
Widget appWithRoutes({
  required String initialLocation,
  required List<RouteBase> routes,
}) {
  return MaterialApp.router(
    theme: AppTheme.light(),
    routerConfig: GoRouter(initialLocation: initialLocation, routes: routes),
  );
}

/// Garante que o alvo esteja visível antes de tocar.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}
