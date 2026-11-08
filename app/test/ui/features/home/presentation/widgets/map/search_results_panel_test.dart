import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/data/models/place_suggestion.dart';
import 'package:meubuzu/ui/core/extensions/line_map_color.dart';
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

      expect(find.text('LINHAS • 1'), findsOneWidget);
      expect(find.text('PARADAS • 1'), findsOneWidget);
      expect(find.text('2 resultados'), findsOneWidget);
      expect(find.text('0301'), findsOneWidget);
      expect(find.text('MOCAMBINHO DUQUE DE CAXIAS'), findsOneWidget);
      expect(find.text('Circular • MOCAMBINHO'), findsOneWidget);
      expect(find.text('T-SANTA FÉ'), findsOneWidget);
      expect(find.text('2362 • Rua B, Loteamento Mário Covas'), findsOneWidget);

      final badge = tester.widget<Container>(
        find
            .ancestor(of: find.text('0301'), matching: find.byType(Container))
            .first,
      );
      expect(
        (badge.decoration! as BoxDecoration).color,
        lineMapColor('0301', 'MOCAMBINHO DUQUE DE CAXIAS'),
      );

      await tester.tap(find.text('0301'));
      await tester.pump();

      expect(selected, _line);
    });

    testWidgets('destaca a linha que está sendo acompanhada no mapa', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          SearchResultsPanel(
            query: '301',
            isLoading: false,
            results: const [_line],
            activeSuggestionId: _line.id,
            statusLabel: '2 de 5 rastreamentos hoje',
            onSelected: (_) {},
          ),
        ),
      );

      expect(find.text('Acompanhando no mapa'), findsOneWidget);
      expect(find.text('2 de 5 rastreamentos hoje'), findsOneWidget);
    });

    testWidgets('destaca a linha já rastreada pelo código', (tester) async {
      await tester.pumpWidget(
        _app(
          SearchResultsPanel(
            query: '301',
            isLoading: false,
            results: const [_line],
            trackedLineCodes: const {'0301'},
            onSelected: (_) {},
          ),
        ),
      );

      expect(find.text('Acompanhando no mapa'), findsOneWidget);
    });

    testWidgets('não destaca linha que não está sendo rastreada', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          SearchResultsPanel(
            query: '301',
            isLoading: false,
            results: const [_line],
            trackedLineCodes: const {'0203'},
            onSelected: (_) {},
          ),
        ),
      );

      expect(find.text('Acompanhando no mapa'), findsNothing);
    });

    testWidgets('mostra o estado vazio com as orientações da busca', (
      tester,
    ) async {
      var edits = 0;

      await tester.pumpWidget(
        _app(
          SearchResultsPanel(
            query: 'Aeroporto',
            isLoading: false,
            results: const [],
            onSelected: (_) {},
            onEditSearch: () => edits++,
          ),
        ),
      );

      expect(find.text('Não encontramos\n“Aeroporto”'), findsOneWidget);
      expect(
        find.text('Nenhuma linha ou parada corresponde à sua busca.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Tente outro nome, número de linha ou código de parada. '
          'Por exemplo: 101, Praça do Ipê ou P-014.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Pesquisar locais, linhas e paradas não consome rastreamentos.',
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Editar busca'));
      await tester.tap(find.text('Editar busca'));
      await tester.pump();

      expect(edits, 1);
    });
  });
}
