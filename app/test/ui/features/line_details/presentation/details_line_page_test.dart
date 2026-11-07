import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/domain/models/bus_stop.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/domain/repositories/details_line_repository.dart';
import 'package:meubuzu/ui/core/theme/app_theme.dart';
import 'package:meubuzu/ui/features/line_details/presentation/details_line_page.dart';

const _line = Line(
  id: '46',
  name: 'MOCAMBINHO DUQUE DE CAXIAS',
  origin: 'MOCAMBINHO',
  destination: 'MOCAMBINHO',
  boardingCode: '0301',
);

const _firstStop = BusStop(
  id: '1',
  code: '174',
  name: 'T-SANTA FÉ',
  address: 'Rua B, Loteamento Mário Covas',
  latitude: -5.1,
  longitude: -42.8,
);

const _secondStop = BusStop(
  id: '2',
  code: '175',
  name: 'CONJUNTO BENTINHO 1',
  address: 'Rua Seis, 8831 - Angelim',
  latitude: -5.2,
  longitude: -42.9,
);

class _FakeDetailsLineRepository implements DetailsLineRepository {
  _FakeDetailsLineRepository({
    this.line,
    this.stops = const [],
    this.error,
    this.gate,
  });

  Line? line;
  List<BusStop> stops;
  Object? error;
  Completer<void>? gate;

  final loadedCodes = <String>[];
  final _lineController = StreamController<Line?>.broadcast();
  final _stopsController = StreamController<List<BusStop>>.broadcast();

  @override
  Stream<Line?> get currentLine => _lineController.stream;

  @override
  Stream<List<BusStop>> get busStops => _stopsController.stream;

  @override
  Future<void> setCurrentLine(String lineCode) async {
    loadedCodes.add(lineCode);

    final gate = this.gate;
    if (gate != null) {
      await gate.future;
    }

    final error = this.error;
    if (error != null) {
      throw error;
    }

    _lineController.add(line);
    _stopsController.add(stops);
  }

  @override
  void dispose() {
    _lineController.close();
    _stopsController.close();
  }
}

Widget _app(DetailsLineRepository repository, {String lineCode = '0301'}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: DetailsLinePage(lineCode: lineCode, repository: repository),
  );
}

void main() {
  group('DetailsLinePage', () {
    testWidgets('mostra carregamento e depois os detalhes da linha', (
      tester,
    ) async {
      final gate = Completer<void>();
      final repository = _FakeDetailsLineRepository(
        line: _line,
        stops: const [_firstStop, _secondStop],
        gate: gate,
      );
      addTearDown(repository.dispose);

      await tester.pumpWidget(_app(repository));

      expect(find.text('Carregando linha...'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Detalhes da linha'), findsOneWidget);
      expect(find.text('0301'), findsOneWidget);
      expect(find.text('MOCAMBINHO DUQUE DE CAXIAS'), findsOneWidget);
      expect(find.text('Circular • MOCAMBINHO'), findsOneWidget);
      expect(find.text('Paradas da linha'), findsOneWidget);
      expect(find.text('T-SANTA FÉ'), findsOneWidget);
      expect(find.text('Rua B, Loteamento Mário Covas'), findsOneWidget);
      expect(find.text('CONJUNTO BENTINHO 1'), findsOneWidget);
      expect(find.text('Rua Seis, 8831 - Angelim'), findsOneWidget);
      expect(find.text('174'), findsOneWidget);
      expect(find.text('175'), findsOneWidget);

      expect(repository.loadedCodes, ['0301']);
    });

    testWidgets('mostra o estado sem paradas cadastradas', (tester) async {
      final repository = _FakeDetailsLineRepository(line: _line);
      addTearDown(repository.dispose);

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      expect(find.text('MOCAMBINHO DUQUE DE CAXIAS'), findsOneWidget);
      expect(
        find.text('Nenhuma parada cadastrada para esta linha no momento.'),
        findsOneWidget,
      );
    });

    testWidgets('mostra o estado de linha não encontrada', (tester) async {
      final repository = _FakeDetailsLineRepository();
      addTearDown(repository.dispose);

      await tester.pumpWidget(_app(repository, lineCode: '9999'));
      await tester.pumpAndSettle();

      expect(find.text('Linha não encontrada'), findsOneWidget);
      expect(
        find.text(
          'Não encontramos a linha 9999 no catálogo. Confira o código e '
          'tente novamente.',
        ),
        findsOneWidget,
      );
      expect(find.text('Voltar'), findsOneWidget);
    });

    testWidgets('mostra erro e permite tentar novamente', (tester) async {
      final repository = _FakeDetailsLineRepository(
        error: StateError('catálogo indisponível'),
      );
      addTearDown(repository.dispose);

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível carregar a linha'), findsOneWidget);

      repository
        ..error = null
        ..line = _line
        ..stops = const [_firstStop];

      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(find.text('MOCAMBINHO DUQUE DE CAXIAS'), findsOneWidget);
      expect(find.text('T-SANTA FÉ'), findsOneWidget);
      expect(repository.loadedCodes, ['0301', '0301']);
    });
  });
}
