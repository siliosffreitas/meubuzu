import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/domain/models/favorite.dart';
import 'package:meubuzu/ui/core/theme/app_theme.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/favorites/favorites_tab.dart';

import '../../../../../../helpers/fake_favorites_repository.dart';

Favorite _favorite(String lineId, String citySlug, String cityLabel) {
  return Favorite.fromJson({
    'id': 'favorite-$lineId',
    'lineId': lineId,
    'line': {
      'id': lineId,
      'name': 'LINHA $lineId',
      'origin': 'TERMINAL',
      'destination': 'BAIRRO $lineId',
      'boardingCode': lineId,
    },
    'city': {
      'slug': citySlug,
      'name': citySlug,
      'label': cityLabel,
      'timezone': 'America/Fortaleza',
    },
  });
}

Widget _app(FakeFavoritesRepository repository, {VoidCallback? onExplore}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: FavoritesTab(
        isSelected: true,
        onExplore: onExplore ?? () {},
        favoritesRepository: repository,
      ),
    ),
  );
}

void main() {
  testWidgets('carrega do endpoint ao exibir e agrupa por cidade', (
    tester,
  ) async {
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
    expect(find.text('Outra - PI'), findsOneWidget);
    expect(find.text('LINHA 101'), findsOneWidget);
    expect(find.text('LINHA 9001'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
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
}
