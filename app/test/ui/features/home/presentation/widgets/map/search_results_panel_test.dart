import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/data/models/place_suggestion.dart';
import 'package:meubuzu/ui/core/theme/app_theme.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/widgets/search_results_panel.dart';

const _line = PlaceSuggestion(
  id: '46',
  code: '0301',
  type: PlaceSuggestionType.line,
  title: 'MOCAMBINHO DUQUE DE CAXIAS',
  subtitle: 'Circular • MOCAMBINHO',
);

const _stop = PlaceSuggestion(
  id: '2362',
  code: '2362',
  type: PlaceSuggestionType.stop,
  title: 'T-SANTA FÉ',
  subtitle: 'Rua B, Loteamento Mário Covas',
  latitude: -5.165446,
  longitude: -42.791169,
);

Widget _app(SearchResultsPanel panel) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Align(alignment: Alignment.topCenter, child: panel),
    ),
  );
}

void main() {
  group('SearchResultsPanel', () {
    testWidgets('separa linhas e paradas e destaca o código da linha', (
      tester,
    ) async {
      PlaceSuggestion? selected;

      await tester.pumpWidget(
        _app(
          SearchResultsPanel(
            query: '301',
            isLoading: false,
            results: const [_line, _stop],
            onSelected: (suggestion) => selected = suggestion,
          ),
        ),
      );

      expect(find.text('Linhas'), findsOneWidget);
      expect(find.text('Paradas'), findsOneWidget);
      expect(find.text('0301'), findsOneWidget);
      expect(find.text('MOCAMBINHO DUQUE DE CAXIAS'), findsOneWidget);
      expect(find.text('Circular • MOCAMBINHO'), findsOneWidget);
      expect(find.text('T-SANTA FÉ'), findsOneWidget);

      await tester.tap(find.text('0301'));
      await tester.pump();

      expect(selected, _line);
    });

    testWidgets('mostra o estado vazio', (tester) async {
      await tester.pumpWidget(
        _app(
          SearchResultsPanel(
            query: 'inexistente',
            isLoading: false,
            results: const [],
            onSelected: (_) {},
          ),
        ),
      );

      expect(find.text('Nenhum resultado'), findsOneWidget);
      expect(
        find.text('Não encontramos linhas ou paradas para “inexistente”.'),
        findsOneWidget,
      );
    });
  });
}
