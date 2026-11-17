import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/domain/models/bus.dart';
import 'package:meubuzu/domain/models/bus_position.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/domain/models/tracked_line.dart';
import 'package:meubuzu/ui/core/extensions/line_map_color.dart';
import 'package:meubuzu/ui/core/theme/app_theme.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/widgets/tracking_panel.dart';

const _line101 = Line(
  id: 'A-104',
  name: 'Jardim das Flores',
  origin: 'Praça do Ipê',
  destination: 'Praça do Ipê',
  boardingCode: '101',
);
const _line203 = Line(
  id: 'A-203',
  name: 'Vila do Sol',
  origin: 'Praça do Ipê',
  destination: 'Praça do Ipê',
  boardingCode: '203',
);
const _line305 = Line(
  id: 'A-305',
  name: 'Circular Parque',
  origin: 'Terminal Central',
  destination: 'Terminal Central',
  boardingCode: '305',
);

TrackedLine _tracked(Line line) {
  return TrackedLine(line: line, route: null, busPositions: const []);
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
      expect(find.text('Praça do Ipê · A-104'), findsOneWidget);
      expect(find.text('Vila do Sol'), findsOneWidget);
      expect(find.text('Praça do Ipê · A-203'), findsOneWidget);
      expect(find.text('Circular Parque'), findsOneWidget);
      expect(find.text('Terminal Central · A-305'), findsOneWidget);
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

  group('trackingLineSubtitle', () {
    test('combina origem e código interno', () {
      expect(trackingLineSubtitle(_line101), 'Praça do Ipê · A-104');
    });

    test('usa apenas a origem quando não há código interno', () {
      const line = Line(
        id: '',
        name: 'Linha',
        origin: 'Centro',
        destination: 'Bairro',
        boardingCode: '0101',
      );

      expect(trackingLineSubtitle(line), 'Centro');
    });

    test('usa o destino quando origem e código estão vazios', () {
      const line = Line(
        id: '',
        name: 'Linha',
        origin: '',
        destination: 'Bairro',
        boardingCode: '0101',
      );

      expect(trackingLineSubtitle(line), 'Bairro');
    });
  });
}
