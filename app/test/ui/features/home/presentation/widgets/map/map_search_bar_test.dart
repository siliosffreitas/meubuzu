import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/ui/core/theme/app_theme.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/widgets/map_search_bar.dart';

Widget _app(MapSearchBar bar) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: bar)),
  );
}

void main() {
  group('MapSearchBar', () {
    testWidgets('aciona a busca ao ser tocada', (tester) async {
      var taps = 0;

      await tester.pumpWidget(_app(MapSearchBar(onTap: () => taps++)));

      expect(find.text('Buscar linha ou parada'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.byType(MapSearchBar));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('mostra a sugestão selecionada no lugar do hint', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(MapSearchBar(text: '875A-10', onTap: () {})),
      );

      expect(find.text('875A-10'), findsOneWidget);
      expect(find.text('Buscar linha ou parada'), findsNothing);
    });
  });
}
