import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meubuzu/domain/models/auth_user.dart';
import 'package:meubuzu/domain/models/city.dart';
import 'package:meubuzu/ui/core/theme/app_theme.dart';
import 'package:meubuzu/ui/features/city_selection/presentation/select_city_page.dart';
import 'package:meubuzu/ui/features/city_selection/presentation/select_city_view_model.dart';
import 'package:meubuzu/ui/routing/app_routes.dart';

import '../../../../helpers/auth_test_helpers.dart';
import '../../../../helpers/fake_auth_repository.dart';
import '../../../../helpers/fake_city_repository.dart';

void main() {
  group('SelectCityPage', () {
    FakeAuthRepository authenticated() {
      return FakeAuthRepository(
        user: const AuthUser(id: 'user-1', email: 'ana@exemplo.com'),
      );
    }

    Future<GoRouter> pumpPage(
      WidgetTester tester, {
      required SelectCityViewModel viewModel,
      bool isChangeMode = false,
      bool canPop = false,
    }) async {
      final router = GoRouter(
        initialLocation: canPop ? AppRoutes.home : AppRoutes.selectCity,
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: AppRoutes.homeName,
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => context.pushNamed(
                  AppRoutes.selectCityName,
                  queryParameters: const {'change': '1'},
                ),
                child: const Text('Abrir troca'),
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.selectCity,
            name: AppRoutes.selectCityName,
            builder: (context, state) => SelectCityPage(
              viewModel: viewModel,
              isChangeMode:
                  isChangeMode || state.uri.queryParameters['change'] == '1',
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      if (canPop) {
        await tester.tap(find.text('Abrir troca'));
        await tester.pumpAndSettle();
      } else {
        await tester.pumpAndSettle();
      }
      return router;
    }

    testWidgets('mostra as cidades e confirma a seleção', (tester) async {
      final auth = authenticated();
      final viewModel = SelectCityViewModel(
        FakeCityRepository(cities: const [testCity]),
        auth,
      );

      await pumpPage(tester, viewModel: viewModel);

      expect(find.text('Escolha sua cidade'), findsOneWidget);
      expect(find.text('Teresina - PI'), findsOneWidget);
      expect(find.text('America/Fortaleza'), findsOneWidget);

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(auth.selectedCities, ['teresina']);
      expect(find.text('Abrir troca'), findsOneWidget);
    });

    testWidgets('mostra o estado vazio e tenta de novo', (tester) async {
      var calls = 0;
      final repository = _CountingCityRepository(() {
        calls++;
        return calls == 1 ? const [] : const [testCity];
      });
      final viewModel = SelectCityViewModel(repository, authenticated());

      await pumpPage(tester, viewModel: viewModel);

      expect(find.text('Nenhuma cidade disponível'), findsOneWidget);

      await tapVisible(tester, find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(find.text('Teresina - PI'), findsOneWidget);
    });

    testWidgets('mostra erro quando não consegue carregar', (tester) async {
      final viewModel = SelectCityViewModel(
        FakeCityRepository(error: Exception('sem rede')),
        authenticated(),
      );

      await pumpPage(tester, viewModel: viewModel);

      expect(
        find.textContaining('Não foi possível carregar as cidades'),
        findsOneWidget,
      );
    });

    testWidgets('mostra o botão de salvar no modo de troca', (tester) async {
      final viewModel = SelectCityViewModel(
        FakeCityRepository(cities: const [testCity]),
        authenticated(),
        isChangeMode: true,
      );

      await pumpPage(tester, viewModel: viewModel, canPop: true);

      expect(find.text('Trocar cidade'), findsOneWidget);
      expect(find.text('Salvar cidade'), findsOneWidget);
      expect(find.text('Voltar'), findsOneWidget);
    });

    testWidgets('salvar no modo de troca volta para a tela anterior', (
      tester,
    ) async {
      final auth = authenticated();
      final viewModel = SelectCityViewModel(
        FakeCityRepository(cities: const [testCity]),
        auth,
        isChangeMode: true,
      );

      await pumpPage(tester, viewModel: viewModel, canPop: true);

      await tester.tap(find.text('Salvar cidade'));
      await tester.pumpAndSettle();

      expect(auth.selectedCities, ['teresina']);
      expect(find.text('Abrir troca'), findsOneWidget);
    });

    testWidgets('não estoura o layout em tela pequena', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final viewModel = SelectCityViewModel(
        FakeCityRepository(cities: const [testCity]),
        authenticated(),
      );

      await pumpPage(tester, viewModel: viewModel);

      expect(tester.takeException(), isNull);
    });
  });
}

/// Repositório que devolve listas diferentes a cada chamada.
class _CountingCityRepository extends FakeCityRepository {
  _CountingCityRepository(this.onFetch);

  final List<City> Function() onFetch;

  @override
  Future<List<City>> fetchActiveCities() async => onFetch();
}
