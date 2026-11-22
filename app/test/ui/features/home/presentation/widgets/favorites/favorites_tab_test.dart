import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/domain/models/city.dart';
import 'package:meubuzu/domain/models/favorite.dart';
import 'package:meubuzu/ui/core/theme/app_theme.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/favorites/favorites_tab.dart';

import '../../../../../../helpers/fake_auth_repository.dart';
import '../../../../../../helpers/fake_favorites_repository.dart';

Favorite _favorite(String boardingCode, String citySlug, String cityLabel) {
  return Favorite.fromJson({
    'boardingCode': boardingCode,
    'line': {
      'name': 'LINHA $boardingCode',
      'origin': 'TERMINAL',
      'destination': 'BAIRRO $boardingCode',
      'boardingCode': boardingCode,
    },
    'city': {
      'slug': citySlug,
      'name': citySlug,
      'label': cityLabel,
      'timezone': 'America/Fortaleza',
    },
  });
}

City _city(String slug, String label) {
  return City(
    slug: slug,
    name: slug,
    label: label,
    state: 'PI',
    country: 'BR',
    timezone: 'America/Fortaleza',
    latitude: -5.09,
    longitude: -42.81,
  );
}

Widget _app(
  FakeFavoritesRepository repository, {
  FakeAuthRepository? auth,
  VoidCallback? onExplore,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: FavoritesTab(
        isSelected: true,
        onExplore: onExplore ?? () {},
        favoritesRepository: repository,
        authRepository:
            auth ??
            FakeAuthRepository(city: _city('teresina', 'Teresina - PI')),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'carrega do endpoint e mostra apenas favoritos da cidade selecionada',
    (tester) async {
      var refreshes = 0;
      final repository = FakeFavoritesRepository([
        _favorite('101', 'teresina', 'Teresina - PI'),
        _favorite('9001', 'outra', 'Outra - PI'),
      ]);
      repository.onRefresh = () async {
        refreshes++;
      };
      addTearDown(repository.dispose);

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      expect(refreshes, 1);
      expect(find.text('Favoritos'), findsOneWidget);
      expect(find.text('Teresina - PI'), findsOneWidget);
      expect(find.text('LINHA 101'), findsOneWidget);
      // Favoritos de outra cidade não aparecem.
      expect(find.text('Outra - PI'), findsNothing);
      expect(find.text('LINHA 9001'), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    },
  );

  testWidgets('trocar de cidade atualiza a lista exibida', (tester) async {
    final repository = FakeFavoritesRepository([
      _favorite('101', 'teresina', 'Teresina - PI'),
      _favorite('9001', 'outra', 'Outra - PI'),
    ]);
    final auth = FakeAuthRepository(city: _city('teresina', 'Teresina - PI'));
    addTearDown(repository.dispose);

    await tester.pumpWidget(_app(repository, auth: auth));
    await tester.pumpAndSettle();

    expect(find.text('LINHA 101'), findsOneWidget);
    expect(find.text('LINHA 9001'), findsNothing);

    await auth.selectCity(_city('outra', 'Outra - PI'));
    await tester.pumpAndSettle();

    expect(find.text('Teresina - PI'), findsNothing);
    expect(find.text('LINHA 101'), findsNothing);
    expect(find.text('Outra - PI'), findsOneWidget);
    expect(find.text('LINHA 9001'), findsOneWidget);
  });

  testWidgets('estrela remove o favorito da lista', (tester) async {
    final repository = FakeFavoritesRepository([
      _favorite('101', 'teresina', 'Teresina - PI'),
    ]);
    addTearDown(repository.dispose);

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.star_rounded));
    await tester.pumpAndSettle();

    expect(repository.removed, ['101']);
    expect(find.text('LINHA 101'), findsNothing);
    expect(find.text('Nenhuma linha favorita'), findsOneWidget);
  });

  testWidgets('mostra erro com ação de tentar novamente', (tester) async {
    final repository = FakeFavoritesRepository()
      ..onRefresh = () async => throw StateError('offline');
    addTearDown(repository.dispose);

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('exibe linhas ordenadas por sgLinha', (tester) async {
    final repository = FakeFavoritesRepository([
      _favorite('2', 'teresina', 'Teresina - PI'),
      _favorite('10', 'teresina', 'Teresina - PI'),
      _favorite('0301', 'teresina', 'Teresina - PI'),
    ]);
    addTearDown(repository.dispose);

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .toList();
    expect(texts.indexOf('LINHA 2'), lessThan(texts.indexOf('LINHA 10')));
    expect(texts.indexOf('LINHA 10'), lessThan(texts.indexOf('LINHA 0301')));
  });
}
