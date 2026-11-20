import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meubuzu/domain/models/bus_stop.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/domain/repositories/details_line_repository.dart';
import 'package:meubuzu/domain/repositories/favorites_repository.dart';
import 'package:meubuzu/ui/core/theme/app_theme.dart';
import 'package:meubuzu/ui/features/line_details/presentation/details_line_page.dart';

import '../../../../helpers/fake_favorites_repository.dart';
import '../../../../helpers/fake_tracking_repository.dart';

const _line = Line(
  name: 'MOCAMBINHO DUQUE DE CAXIAS',
  origin: 'MOCAMBINHO',
  destination: 'MOCAMBINHO',
  boardingCode: '0301',
);

const _firstStop = BusStop(
  code: '174',
  name: 'T-SANTA FÉ',
  address: 'Rua B, Loteamento Mário Covas',
  latitude: -5.1,
  longitude: -42.8,
);

const _secondStop = BusStop(
  code: '175',
  name: 'CONJUNTO BENTINHO 1',
  address: 'Rua Seis, 8831 - Angelim',
  latitude: -5.2,
  longitude: -42.9,
);

BusStop _stop(int position) {
  return BusStop(
    code: '10$position',
    name: 'PARADA $position',
    address: 'Rua $position',
    latitude: -5.0 - (position * 0.01),
    longitude: -42.8,
  );
}

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

Widget _app(
  DetailsLineRepository repository, {
  String lineCode = '0301',
  FakeTrackingRepository? trackingRepository,
  FavoritesRepository? favoritesRepository,
}) {
  final tracking = trackingRepository ?? FakeTrackingRepository();
  if (trackingRepository == null) {
    addTearDown(tracking.dispose);
  }
  return MaterialApp(
    theme: AppTheme.light(),
    home: DetailsLinePage(
      lineCode: lineCode,
      repository: repository,
      trackingRepository: tracking,
      favoritesRepository: favoritesRepository,
    ),
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
      expect(find.text('Itinerário · 2 paradas'), findsOneWidget);
      expect(find.text('Não acompanhada'), findsOneWidget);
      expect(find.text('T-SANTA FÉ · 174'), findsOneWidget);
      expect(find.text('CONJUNTO BENTINHO 1 · 175'), findsOneWidget);
      expect(find.text('Começar a acompanhar'), findsOneWidget);

      expect(repository.loadedCodes, ['0301']);
    });

    testWidgets('inicia o rastreamento e volta para a Home ao tocar no botão', (
      tester,
    ) async {
      final repository = _FakeDetailsLineRepository(
        line: _line,
        stops: const [_firstStop, _secondStop],
      );
      addTearDown(repository.dispose);

      final trackingRepository = FakeTrackingRepository();
      addTearDown(trackingRepository.dispose);
      Object? homeExtra;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) {
              homeExtra = state.extra;
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => context.pushNamed('details'),
                    child: const Text('Abrir detalhes'),
                  ),
                ),
              );
            },
          ),
          GoRoute(
            path: '/details',
            name: 'details',
            builder: (context, state) => DetailsLinePage(
              lineCode: '0301',
              repository: repository,
              trackingRepository: trackingRepository,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );

      await tester.tap(find.text('Abrir detalhes'));
      await tester.pumpAndSettle();

      expect(find.text('Começar a acompanhar'), findsOneWidget);

      await tester.tap(find.text('Começar a acompanhar'));
      await tester.pumpAndSettle();

      expect(trackingRepository.startedCodes, ['0301']);
      expect(find.text('Abrir detalhes'), findsOneWidget);
      expect(find.text('Começar a acompanhar'), findsNothing);
      expect(homeExtra, 0);
    });

    testWidgets('linha não rastreada não mostra status de acompanhada', (
      tester,
    ) async {
      const otherLine = Line(
        name: 'VALE DO GAVIAO',
        origin: 'ORIGEM',
        destination: 'DESTINO',
        boardingCode: '0245',
      );
      final repository = _FakeDetailsLineRepository(
        line: otherLine,
        stops: const [_firstStop],
      );
      addTearDown(repository.dispose);
      final trackingRepository = FakeTrackingRepository(
        trackedLines: [trackedLineFor(_line)],
      );
      addTearDown(trackingRepository.dispose);

      await tester.pumpWidget(
        _app(
          repository,
          lineCode: '0245',
          trackingRepository: trackingRepository,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Não acompanhada'), findsOneWidget);
      expect(find.text('Começar a acompanhar'), findsOneWidget);
      expect(find.text('Acompanhando no mapa'), findsNothing);
      expect(find.text('Remover do mapa'), findsNothing);
    });

    testWidgets('mostra o status de acompanhada e remove do mapa', (
      tester,
    ) async {
      final repository = _FakeDetailsLineRepository(
        line: _line,
        stops: const [_firstStop, _secondStop],
      );
      addTearDown(repository.dispose);
      final trackingRepository = FakeTrackingRepository(
        trackedLines: [trackedLineFor(_line)],
      );
      addTearDown(trackingRepository.dispose);

      bool? removalResult;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    removalResult = await context.pushNamed<bool>('details');
                  },
                  child: const Text('Abrir detalhes'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/details',
            name: 'details',
            builder: (context, state) => DetailsLinePage(
              lineCode: '0301',
              repository: repository,
              trackingRepository: trackingRepository,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );

      await tester.tap(find.text('Abrir detalhes'));
      await tester.pumpAndSettle();

      expect(find.text('Acompanhando no mapa'), findsOneWidget);
      expect(find.text('Remover do mapa'), findsOneWidget);
      expect(find.text('Não acompanhada'), findsNothing);
      expect(find.text('Começar a acompanhar'), findsNothing);
      expect(
        find.text('Iniciar usa 1 de 5 rastreamentos por dia.'),
        findsNothing,
      );

      await tester.tap(find.text('Remover do mapa'));
      await tester.pumpAndSettle();

      expect(trackingRepository.stoppedCodes, ['0301']);
      expect(removalResult, isFalse);
      expect(find.text('Abrir detalhes'), findsOneWidget);
    });

    testWidgets('volta a mostrar o início quando a linha sai do mapa', (
      tester,
    ) async {
      final repository = _FakeDetailsLineRepository(
        line: _line,
        stops: const [_firstStop, _secondStop],
      );
      addTearDown(repository.dispose);
      final trackingRepository = FakeTrackingRepository(
        trackedLines: [trackedLineFor(_line)],
      );
      addTearDown(trackingRepository.dispose);

      await tester.pumpWidget(
        _app(repository, trackingRepository: trackingRepository),
      );
      await tester.pumpAndSettle();

      expect(find.text('Acompanhando no mapa'), findsOneWidget);
      expect(find.text('Remover do mapa'), findsOneWidget);

      trackingRepository.emit(const []);
      await tester.pumpAndSettle();

      expect(find.text('Não acompanhada'), findsOneWidget);
      expect(find.text('Começar a acompanhar'), findsOneWidget);
      expect(find.text('Remover do mapa'), findsNothing);
    });

    testWidgets('alterna entre as 3 primeiras paradas e todas', (tester) async {
      final stops = [
        for (var position = 1; position <= 7; position++) _stop(position),
      ];
      final repository = _FakeDetailsLineRepository(line: _line, stops: stops);
      addTearDown(repository.dispose);

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      for (var position = 1; position <= 3; position++) {
        expect(find.textContaining('PARADA $position'), findsOneWidget);
      }
      expect(find.textContaining('PARADA 4'), findsNothing);
      expect(find.textContaining('PARADA 5'), findsNothing);
      expect(find.text('Mostrar mais'), findsOneWidget);
      expect(find.text('Mostrar menos'), findsNothing);

      await tester.ensureVisible(find.text('Mostrar mais'));
      await tester.tap(find.text('Mostrar mais'));
      await tester.pumpAndSettle();

      expect(find.text('Mostrar mais'), findsNothing);
      expect(find.textContaining('PARADA 4'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.textContaining('PARADA 7'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('PARADA 7'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Mostrar menos'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Mostrar menos'), findsOneWidget);

      await tester.tap(find.text('Mostrar menos'));
      await tester.pumpAndSettle();

      expect(find.text('Mostrar menos'), findsNothing);
      expect(find.text('Mostrar mais'), findsOneWidget);
      expect(find.textContaining('PARADA 4'), findsNothing);
      expect(find.textContaining('PARADA 5'), findsNothing);
    });

    testWidgets('não mostra o botão quando há 3 paradas ou menos', (
      tester,
    ) async {
      final stops = [
        for (var position = 1; position <= 3; position++) _stop(position),
      ];
      final repository = _FakeDetailsLineRepository(line: _line, stops: stops);
      addTearDown(repository.dispose);

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      expect(find.textContaining('PARADA 3'), findsOneWidget);
      expect(find.text('Mostrar mais'), findsNothing);
    });

    testWidgets('mostra o estado sem paradas cadastradas', (tester) async {
      final repository = _FakeDetailsLineRepository(line: _line);
      addTearDown(repository.dispose);

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      expect(find.text('MOCAMBINHO DUQUE DE CAXIAS'), findsOneWidget);
      expect(find.text('Itinerário · 0 paradas'), findsOneWidget);
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
      expect(find.widgetWithText(OutlinedButton, 'Voltar'), findsOneWidget);
      expect(find.text('Começar a acompanhar'), findsNothing);
    });

    testWidgets('mostra erro e permite tentar novamente', (tester) async {
      final repository = _FakeDetailsLineRepository(
        error: StateError('catálogo indisponível'),
      );
      addTearDown(repository.dispose);

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível carregar a linha'), findsOneWidget);
      expect(find.text('Começar a acompanhar'), findsNothing);

      repository
        ..error = null
        ..line = _line
        ..stops = const [_firstStop];

      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(find.text('MOCAMBINHO DUQUE DE CAXIAS'), findsOneWidget);
      expect(find.textContaining('T-SANTA FÉ'), findsOneWidget);
      expect(repository.loadedCodes, ['0301', '0301']);
    });

    testWidgets('estrela fica visível e desabilitada até a linha carregar', (
      tester,
    ) async {
      final gate = Completer<void>();
      final repository = _FakeDetailsLineRepository(
        line: _line,
        stops: const [_firstStop],
        gate: gate,
      );
      final favorites = FakeFavoritesRepository();
      addTearDown(repository.dispose);
      addTearDown(favorites.dispose);

      await tester.pumpWidget(_app(repository, favoritesRepository: favorites));

      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
      var button = tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byIcon(Icons.star_outline_rounded),
              matching: find.byType(IconButton),
            )
            .first,
      );
      expect(button.onPressed, isNull);

      gate.complete();
      await tester.pumpAndSettle();

      button = tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byIcon(Icons.star_outline_rounded),
              matching: find.byType(IconButton),
            )
            .first,
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('estrela preenchida remove o favorito ao ser tocada', (
      tester,
    ) async {
      final repository = _FakeDetailsLineRepository(
        line: _line,
        stops: const [_firstStop],
      );
      final favorites = FakeFavoritesRepository();
      addTearDown(repository.dispose);
      addTearDown(favorites.dispose);
      await favorites.add(_line.boardingCode);

      await tester.pumpWidget(_app(repository, favoritesRepository: favorites));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.star_rounded));
      await tester.pumpAndSettle();

      expect(favorites.removed, [_line.boardingCode]);
      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
    });

    testWidgets('estrela permanece desabilitada sem repositório de favoritos', (
      tester,
    ) async {
      final repository = _FakeDetailsLineRepository(
        line: _line,
        stops: const [_firstStop],
      );
      addTearDown(repository.dispose);

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      final button = tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byIcon(Icons.star_outline_rounded),
              matching: find.byType(IconButton),
            )
            .first,
      );
      expect(button.onPressed, isNull);
    });
  });
}
