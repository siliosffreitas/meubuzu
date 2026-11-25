import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/domain/models/line_direction.dart';
import 'package:meubuzu/domain/models/tracked_line.dart';
import 'package:meubuzu/ui/core/theme/app_theme.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/widgets/direction_selection_sheet.dart';

const _line = Line(
  name: 'Linha 1012',
  origin: 'Terminal A',
  destination: 'Jardim B',
  boardingCode: '1012-10',
);

TrackedLine _tracked(List<LineDirection> directions, {int direction = 0}) {
  return TrackedLine(
    line: _line,
    route: null,
    busPositions: const [],
    direction: direction,
    directions: directions,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('DirectionSelectionSheet', () {
    testWidgets('mostra estado vazio sem itinerários', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DirectionSelectionSheet(
            tracked: TrackedLine(
              line: _line,
              route: null,
              busPositions: const [],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('direction-selection-empty')), findsOneWidget);
      expect(
        find.text('Esta linha ainda não possui itinerário cadastrado.'),
        findsOneWidget,
      );
      expect(find.text('Sentido 1'), findsNothing);
    });

    testWidgets('marca o sentido atual e mostra a quantidade de paradas', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DirectionSelectionSheet(
            tracked: _tracked([
              const LineDirection(
                value: 0,
                label: 'Terminal A → Jardim B',
                hasRoute: true,
                stopCount: 42,
              ),
              const LineDirection(
                value: 1,
                label: 'Jardim B → Terminal A',
                hasRoute: true,
                stopCount: 43,
              ),
            ]),
          ),
        ),
      );

      expect(find.text('Terminal A → Jardim B'), findsOneWidget);
      expect(find.text('42 paradas'), findsOneWidget);
      expect(find.text('43 paradas'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('desabilita o sentido sem traçado', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DirectionSelectionSheet(
            tracked: _tracked([
              const LineDirection(value: 0, label: 'Ida', hasRoute: true),
              const LineDirection(value: 1, label: 'Volta', hasRoute: false),
            ]),
          ),
        ),
      );

      final option = tester.widget<InkWell>(
        find.byKey(const Key('direction-option-1012-10-1')),
      );
      expect(option.onTap, isNull);
      expect(find.text('Sem traçado'), findsOneWidget);
    });

    testWidgets('devolve o sentido tocado', (tester) async {
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selected = await showModalBottomSheet<int>(
                    context: context,
                    builder: (_) => DirectionSelectionSheet(
                      tracked: _tracked([
                        const LineDirection(
                          value: 0,
                          label: 'Ida',
                          hasRoute: true,
                        ),
                        const LineDirection(
                          value: 1,
                          label: 'Volta',
                          hasRoute: true,
                        ),
                      ]),
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('direction-option-1012-10-1')));
      await tester.pumpAndSettle();

      expect(selected, 1);
    });
  });
}
