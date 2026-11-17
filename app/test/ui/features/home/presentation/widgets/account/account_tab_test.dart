import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meubuzu/domain/models/auth_user.dart';
import 'package:meubuzu/ui/core/theme/app_theme.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/account/account_tab.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/account/account_view_model.dart';
import 'package:meubuzu/ui/routing/app_routes.dart';

import '../../../../../../helpers/auth_test_helpers.dart';
import '../../../../../../helpers/fake_auth_repository.dart';

void main() {
  group('aba Conta', () {
    testWidgets('mostra o e-mail e o nível de acesso', (tester) async {
      final repository = FakeAuthRepository(
        user: const AuthUser(
          id: 'user-1',
          email: 'ana.lima@exemplo.com',
          accessLevel: 'trial',
        ),
      );
      final viewModel = AccountViewModel(repository);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: AccountTab(viewModel: viewModel)),
        ),
      );

      expect(find.text('ana.lima@exemplo.com'), findsOneWidget);
      expect(find.text('Teste de 7 dias'), findsOneWidget);
    });

    testWidgets('sair encerra a sessão e apaga a cidade selecionada', (
      tester,
    ) async {
      final repository = FakeAuthRepository(
        user: const AuthUser(id: 'user-1', email: 'ana.lima@exemplo.com'),
        city: testCity,
      );
      final viewModel = AccountViewModel(repository);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: AccountTab(viewModel: viewModel)),
        ),
      );

      expect(find.text('Teresina - PI'), findsOneWidget);

      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();

      expect(repository.logoutCalls, 1);
      expect(repository.isAuthenticated, isFalse);
      expect(repository.selectedCity, isNull);
      expect(find.text('Conta sem sessão'), findsOneWidget);
      expect(find.text('Nenhuma cidade selecionada'), findsOneWidget);
    });

    test('expõe o nível de acesso padrão sem sessão', () {
      final viewModel = AccountViewModel(FakeAuthRepository());

      expect(viewModel.email, isNull);
      expect(viewModel.accessLevel, 'catalog_only');

      viewModel.dispose();
    });

    testWidgets('mostra a cidade selecionada e abre a troca', (tester) async {
      final repository = FakeAuthRepository(
        user: const AuthUser(id: 'user-1', email: 'ana.lima@exemplo.com'),
        city: testCity,
      );
      final viewModel = AccountViewModel(repository);

      final router = GoRouter(
        initialLocation: AppRoutes.home,
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: AppRoutes.homeName,
            builder: (context, state) =>
                Scaffold(body: AccountTab(viewModel: viewModel)),
          ),
          GoRoute(
            path: AppRoutes.selectCity,
            name: AppRoutes.selectCityName,
            builder: (context, state) => Scaffold(
              body: Text('Troca ${state.uri.queryParameters['change']}'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );

      expect(find.text('Teresina - PI'), findsOneWidget);
      expect(find.text('America/Fortaleza'), findsOneWidget);

      await tester.tap(find.text('Trocar'));
      await tester.pumpAndSettle();

      expect(find.text('Troca 1'), findsOneWidget);
    });

    testWidgets('sem cidade mostra o botão para escolher', (tester) async {
      final repository = FakeAuthRepository(
        user: const AuthUser(id: 'user-1', email: 'ana.lima@exemplo.com'),
      );
      final viewModel = AccountViewModel(repository);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: AccountTab(viewModel: viewModel)),
        ),
      );

      expect(find.text('Nenhuma cidade selecionada'), findsOneWidget);
      expect(find.text('Escolher'), findsOneWidget);
    });
  });
}
