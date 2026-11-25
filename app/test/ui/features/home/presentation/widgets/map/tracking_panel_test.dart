import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/domain/models/bus.dart';
import 'package:meubuzu/domain/models/bus_position.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/domain/models/line_direction.dart';
import 'package:meubuzu/domain/models/tracked_line.dart';
import 'package:meubuzu/ui/core/extensions/line_map_color.dart';
import 'package:meubuzu/ui/core/theme/app_theme.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/widgets/tracking_panel.dart';

const _line101 = Line(
  name: 'Jardim das Flores',
  origin: 'Praça do Ipê',
  destination: 'Praça do Ipê',
  boardingCode: '101',
);
const _line203 = Line(
  name: 'Vila do Sol',
  origin: 'Praça do Ipê',
  destination: 'Praça do Ipê',
  boardingCode: '203',
);
const _line305 = Line(
  name: 'Circular Parque',
  origin: 'Terminal Central',
  destination: 'Terminal Central',
  boardingCode: '305',
);

TrackedLine _tracked(Line line) {
  return TrackedLine(line: line, route: null, busPositions: const []);
}

TrackedLine _trackedWithDirections(
  Line line,
  List<LineDirection> directions, {
  int direction = 0,
}) {
  return TrackedLine(
    line: line,
    route: null,
    busPositions: const [],
    direction: direction,
    directions: directions,
  );
}

BusPosition _position({bool isStale = false, String? dataMode}) {
  return BusPosition(
    bus: Bus(code: '4171'),
    lineCode: '101',
    latitude: -5.1,
    longitude: -42.8,
    capturedAt: DateTime.utc(2026, 11, 17, 15),
    isStale: isStale,
    dataMode: dataMode,
  );
}

TrackedLine _trackedWithPositions(Line line, List<BusPosition> positions) {
  return TrackedLine(line: line, route: null, busPositions: positions);
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Align(alignment: Alignment.bottomCenter, child: child),
    ),
  );
}

/// Host que remove a linha da lista quando o painel sinaliza a remoção.
class _RemovablePanel extends StatefulWidget {
  const _RemovablePanel(this.lines, {this.onRemove});

  final List<TrackedLine> lines;
  final ValueChanged<TrackedLine>? onRemove;

  @override
  State<_RemovablePanel> createState() => _RemovablePanelState();
}

class _RemovablePanelState extends State<_RemovablePanel> {
  late List<TrackedLine> _lines = widget.lines;

  @override
  Widget build(BuildContext context) {
    return TrackingPanel(
      trackedLines: _lines,
      onRemoveLine: (tracked) {
        widget.onRemove?.call(tracked);
        setState(() {
          _lines = [
            for (final line in _lines)
              if (!identical(line, tracked)) line,
          ];
        });
      },
    );
  }
}

void main() {
  group('TrackingPanel', () {
    testWidgets('não renderiza nada sem linhas acompanhadas', (tester) async {
      await tester.pumpWidget(_wrap(const TrackingPanel(trackedLines: [])));

      expect(find.byKey(const Key('tracking-panel')), findsNothing);
    });

    testWidgets('exibe todas as linhas e o horário de atualização', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TrackingPanel(
            trackedLines: [
              _tracked(_line101),
              _tracked(_line203),
              _tracked(_line305),
            ],
            updatedAt: DateTime(2026, 11, 8, 8, 42, 15),
          ),
        ),
      );

      expect(find.text('3 LINHAS NO MAPA'), findsOneWidget);
      expect(find.text('Atualizado 08:42:15'), findsOneWidget);

      expect(find.text('Jardim das Flores'), findsOneWidget);
      expect(find.text('Itinerário não disponível'), findsNWidgets(3));
      expect(find.text('Vila do Sol'), findsOneWidget);
      expect(find.text('Circular Parque'), findsOneWidget);
    });

    testWidgets('usa o singular quando há apenas uma linha', (tester) async {
      await tester.pumpWidget(
        _wrap(TrackingPanel(trackedLines: [_tracked(_line101)])),
      );

      expect(find.text('1 LINHA NO MAPA'), findsOneWidget);
    });

    testWidgets('usa a mesma cor de identificação da linha no badge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(TrackingPanel(trackedLines: [_tracked(_line101)])),
      );

      final badge = tester.widget<Container>(
        find.byKey(const Key('tracking-line-badge-101')),
      );
      final decoration = badge.decoration! as BoxDecoration;

      expect(decoration.color, _line101.mapColor);
    });

    testWidgets('abre a linha tocada pelo callback', (tester) async {
      final tapped = <TrackedLine>[];

      await tester.pumpWidget(
        _wrap(
          TrackingPanel(
            trackedLines: [_tracked(_line101), _tracked(_line203)],
            onLineTap: tapped.add,
          ),
        ),
      );

      await tester.tap(find.text('Vila do Sol'));
      await tester.pump();

      expect(tapped.map((tracked) => tracked.line.name), ['Vila do Sol']);
    });

    testWidgets('remove a linha ao arrastar para o lado', (tester) async {
      final removed = <TrackedLine>[];
      final tapped = <TrackedLine>[];

      await tester.pumpWidget(
        _wrap(
          TrackingPanel(
            trackedLines: [_tracked(_line101), _tracked(_line203)],
            onLineTap: tapped.add,
            onRemoveLine: removed.add,
          ),
        ),
      );

      await tester.fling(
        find.byKey(const Key('tracking-line-tile-203')),
        const Offset(-500, 0),
        1200,
      );
      await tester.pumpAndSettle();

      expect(removed.map((tracked) => tracked.line.name), ['Vila do Sol']);
      expect(tapped, isEmpty);
    });

    testWidgets('a linha removida desaparece da lista', (tester) async {
      final removed = <TrackedLine>[];

      await tester.pumpWidget(
        _wrap(
          _RemovablePanel(
            [_tracked(_line101), _tracked(_line203)],
            onRemove: removed.add,
          ),
        ),
      );

      expect(find.byKey(const Key('tracking-line-tile-101')), findsOneWidget);
      expect(find.byKey(const Key('tracking-line-tile-203')), findsOneWidget);

      await tester.fling(
        find.byKey(const Key('tracking-line-tile-101')),
        const Offset(-500, 0),
        1200,
      );
      await tester.pumpAndSettle();

      expect(removed.map((tracked) => tracked.line.name), [
        'Jardim das Flores',
      ]);
      expect(find.byKey(const Key('tracking-line-tile-101')), findsNothing);
      expect(find.byKey(const Key('tracking-line-tile-203')), findsOneWidget);
      expect(find.text('1 LINHA NO MAPA'), findsOneWidget);
    });

    testWidgets('arraste vertical na linha não remove o rastreamento', (
      tester,
    ) async {
      final removed = <TrackedLine>[];

      await tester.pumpWidget(
        _wrap(
          TrackingPanel(
            trackedLines: [_tracked(_line101)],
            onRemoveLine: removed.add,
          ),
        ),
      );

      await tester.fling(
        find.byKey(const Key('tracking-line-tile-101')),
        const Offset(0, 120),
        600,
      );
      await tester.pumpAndSettle();

      expect(removed, isEmpty);
      expect(find.byKey(const Key('tracking-line-tile-101')), findsOneWidget);
    });

    testWidgets('não falha ao tocar sem callback configurado', (tester) async {
      await tester.pumpWidget(
        _wrap(TrackingPanel(trackedLines: [_tracked(_line101)])),
      );

      await tester.tap(find.text('Jardim das Flores'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('minimiza pelo cabeçalho e expande pela alça', (tester) async {
      await tester.pumpWidget(
        _wrap(TrackingPanel(trackedLines: [_tracked(_line101)])),
      );

      expect(find.byKey(const Key('tracking-panel-list')), findsOneWidget);
      expect(find.text('Jardim das Flores'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tracking-panel-header')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tracking-panel-list')), findsNothing);
      expect(find.text('Jardim das Flores'), findsNothing);
      expect(find.text('1 LINHA NO MAPA'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tracking-panel-handle')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tracking-panel-list')), findsOneWidget);
      expect(find.text('Jardim das Flores'), findsOneWidget);
    });

    testWidgets('minimiza e expande arrastando a alça', (tester) async {
      await tester.pumpWidget(
        _wrap(TrackingPanel(trackedLines: [_tracked(_line101)])),
      );

      await tester.fling(
        find.byKey(const Key('tracking-panel-handle')),
        const Offset(0, 120),
        600,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tracking-panel-list')), findsNothing);

      await tester.fling(
        find.byKey(const Key('tracking-panel-handle')),
        const Offset(0, -120),
        600,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tracking-panel-list')), findsOneWidget);
    });

    testWidgets('não exibe previsão de chegada nem favorito', (tester) async {
      await tester.pumpWidget(
        _wrap(TrackingPanel(trackedLines: [_tracked(_line101)])),
      );

      expect(find.text('6 min'), findsNothing);
      expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('avisa quando há posições de demonstração', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TrackingPanel(
            trackedLines: [_trackedWithPositions(_line101, [_position(dataMode: 'demo')])],
          ),
        ),
      );

      expect(find.byKey(const Key('tracking-panel-notice')), findsOneWidget);
      expect(find.text('Dados de demonstração'), findsOneWidget);
      expect(find.text('Posições antigas'), findsNothing);
    });

    testWidgets('avisa quando há posições antigas e demonstração', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TrackingPanel(
            trackedLines: [
              _trackedWithPositions(_line101, [
                _position(dataMode: 'demo', isStale: true),
              ]),
            ],
          ),
        ),
      );

      expect(find.byKey(const Key('tracking-panel-notice')), findsOneWidget);
      expect(find.text('Dados de demonstração · Posições antigas'), findsOneWidget);
    });

    testWidgets('não exibe aviso para posições reais recentes', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TrackingPanel(
            trackedLines: [_trackedWithPositions(_line101, [_position(dataMode: 'live')])],
          ),
        ),
      );

      expect(find.byKey(const Key('tracking-panel-notice')), findsNothing);
    });
  });

  group('seleção de sentido', () {
    testWidgets('abre o modal mesmo sem nenhum itinerário', (tester) async {
      await tester.pumpWidget(
        _wrap(TrackingPanel(trackedLines: [_tracked(_line101)])),
      );

      await tester.tap(
        find.byKey(const Key('tracking-line-direction-101')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sentido da linha'), findsOneWidget);
      expect(find.byKey(const Key('direction-selection-empty')), findsOneWidget);
    });

    testWidgets('abre o modal com um único sentido já marcado', (tester) async {
      final selected = <int>[];
      await tester.pumpWidget(
        _wrap(
          TrackingPanel(
            trackedLines: [
              _trackedWithDirections(
                _line101,
                const [
                  LineDirection(
                    value: 0,
                    label: 'Circular • Praça do Ipê',
                    hasRoute: true,
                  ),
                ],
              ),
            ],
            onDirectionSelected: (tracked, direction) async {
              selected.add(direction);
            },
          ),
        ),
      );

      expect(find.text('Circular • Praça do Ipê'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tracking-line-direction-101')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('direction-option-101-0')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('direction-option-101-0')));
      await tester.pumpAndSettle();

      expect(selected, isEmpty);
      expect(find.text('Sentido da linha'), findsNothing);
    });

    testWidgets('seleciona outro sentido pelo modal', (tester) async {
      final selected = <int>[];
      await tester.pumpWidget(
        _wrap(
          TrackingPanel(
            trackedLines: [
              _trackedWithDirections(
                _line203,
                const [
                  LineDirection(
                    value: 0,
                    label: 'Terminal → Bairro',
                    hasRoute: true,
                  ),
                  LineDirection(
                    value: 1,
                    label: 'Bairro → Terminal',
                    hasRoute: true,
                  ),
                ],
              ),
            ],
            onDirectionSelected: (tracked, direction) async {
              selected.add(direction);
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('tracking-line-direction-203')));
      await tester.pumpAndSettle();

      expect(find.text('Escolha qual itinerário será exibido no mapa.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('direction-option-203-1')));
      await tester.pumpAndSettle();

      expect(selected, [1]);
      expect(find.text('Sentido da linha'), findsNothing);
    });
  });

  group('trackingLineSubtitle', () {
    test('usa o rótulo do sentido selecionado', () {
      final tracked = _trackedWithDirections(
        _line101,
        const [
          LineDirection(value: 0, label: 'Circular • Praça do Ipê'),
          LineDirection(value: 1, label: 'Sentido Parque'),
        ],
        direction: 1,
      );

      expect(trackingLineSubtitle(tracked), 'Sentido Parque');
    });

    test('usa o rótulo da linha quando o sentido não tem rótulo', () {
      const line = Line(
        name: 'Linha',
        origin: 'Centro',
        destination: 'Bairro',
        boardingCode: '0101',
      );
      final tracked = _trackedWithDirections(
        line,
        const [LineDirection(value: 2, label: '', hasRoute: true)],
        direction: 2,
      );

      expect(trackingLineSubtitle(tracked), 'Sentido Bairro');
    });

    test('indica quando a linha não possui itinerário', () {
      expect(trackingLineSubtitle(_tracked(_line101)), 'Itinerário não disponível');
    });
  });
}
