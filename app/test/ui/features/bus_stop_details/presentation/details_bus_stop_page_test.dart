import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/domain/models/bus_stop.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/domain/models/tracked_line.dart';
import 'package:meubuzu/domain/models/user_coordinates.dart';
import 'package:meubuzu/domain/repositories/details_bus_stop_repository.dart';
import 'package:meubuzu/domain/repositories/tracking_repository.dart';
import 'package:meubuzu/domain/repositories/user_location_repository.dart';
import 'package:meubuzu/ui/core/theme/app_theme.dart';
import 'package:meubuzu/ui/features/bus_stop_details/presentation/details_bus_stop_page.dart';

const _busStop = BusStop(
  id: '1',
  code: '174',
  name: 'PRAÇA DO IPÊ',
  address: 'Rua do Mercado, 180 · em frente à praça',
  latitude: -5.1,
  longitude: -42.8,
);

const _line = Line(
  id: '46',
  name: 'JARDIM DAS FLORES',
  origin: 'TERMINAL CENTRAL',
  destination: 'JARDIM DAS FLORES',
  boardingCode: '101',
);

const _otherLine = Line(
  id: '203',
  name: 'VILA DO SOL',
  origin: 'TERMINAL CENTRAL',
  destination: 'VILA DO SOL',
  boardingCode: '203',
);

class _FakeDetailsBusStopRepository implements DetailsBusStopRepository {
  _FakeDetailsBusStopRepository({
    this.busStop,
    this.busStopLines = const [],
    this.error,
    this.gate,
  });

  BusStop? busStop;
  List<Line> busStopLines;
  Object? error;
  Completer<void>? gate;

  final loadedCodes = <String>[];
  final _busStopController = StreamController<BusStop?>.broadcast();
  final _linesController = StreamController<List<Line>>.broadcast();

  @override
  Stream<BusStop?> get currentBusStop => _busStopController.stream;

  @override
  Stream<List<Line>> get lines => _linesController.stream;

  @override
  Future<void> setCurrentBusStop(String busStopCode) async {
    loadedCodes.add(busStopCode);

    final gate = this.gate;
    if (gate != null) {
      await gate.future;
    }

    final error = this.error;
    if (error != null) {
      throw error;
    }

    _busStopController.add(busStop);
    _linesController.add(busStopLines);
  }

  @override
  void dispose() {
    _busStopController.close();
    _linesController.close();
  }
}

class _FakeUserLocationRepository implements UserLocationRepository {
  final _locationController = StreamController<UserCoordinates>.broadcast();
  final _nearbyStopsController = StreamController<List<BusStop>>.broadcast();

  void emitLocation(UserCoordinates position) {
    _locationController.add(position);
  }

  @override
  Stream<UserCoordinates> get location => _locationController.stream;

  @override
  Stream<List<BusStop>> get nearbyStops => _nearbyStopsController.stream;

  @override
  Future<void> refresh({bool requestPermission = true}) async {}

  @override
  Future<void> openLocationSettings() async {}

  @override
  Future<void> openAppSettings() async {}

  @override
  void dispose() {
    _locationController.close();
    _nearbyStopsController.close();
  }
}

class _FakeTrackingRepository implements TrackingRepository {
  final _controller = StreamController<List<TrackedLine>>.broadcast();

  void emit(List<TrackedLine> lines) => _controller.add(lines);

  @override
  Stream<List<TrackedLine>> get trackingRoutes => _controller.stream;

  @override
  Future<TrackedLine?> startTracking(String lineCode) async => null;

  @override
  Future<void> stopTracking(String lineCode) async {}

  @override
  void dispose() => _controller.close();
}

TrackedLine _trackedLine(String code) {
  return TrackedLine(
    line: Line(
      // O rastreamento usa o `sgLinha`; o `id` é o código interno do catálogo.
      id: 'codigo-interno-$code',
      name: 'LINHA RASTREADA',
      origin: 'TERMINAL CENTRAL',
      destination: 'JARDIM DAS FLORES',
      boardingCode: code,
    ),
    route: null,
    busPositions: const [],
  );
}

Widget _app(
  DetailsBusStopRepository repository, {
  String busStopCode = '174',
  UserLocationRepository? locationRepository,
  TrackingRepository? trackingRepository,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: DetailsBusStopPage(
      busStopCode: busStopCode,
      repository: repository,
      locationRepository: locationRepository,
      trackingRepository: trackingRepository,
      mapPreviewBuilder: (_) =>
          const SizedBox(key: Key('map-preview'), height: 190),
    ),
  );
}

void main() {
  group('DetailsBusStopPage', () {
    testWidgets('mostra carregamento e depois os detalhes da parada', (
      tester,
    ) async {
      final repository = _FakeDetailsBusStopRepository(
        busStop: _busStop,
        busStopLines: const [_line, _otherLine],
        gate: Completer<void>(),
      );
      addTearDown(repository.dispose);

      await tester.pumpWidget(_app(repository));
      await tester.pump();

      expect(find.text('Carregando parada...'), findsOneWidget);

      repository.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.text('Detalhes da parada'), findsOneWidget);
      expect(find.text('PARADA · 174'), findsOneWidget);
      expect(find.text('PRAÇA DO IPÊ'), findsOneWidget);
      expect(
        find.text('Rua do Mercado, 180 · em frente à praça'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('map-preview')), findsOneWidget);
      expect(find.text('Linhas que passam aqui'), findsOneWidget);
      expect(find.text('2 linhas'), findsOneWidget);
      expect(find.text('JARDIM DAS FLORES'), findsOneWidget);
      expect(find.text('TERMINAL CENTRAL → JARDIM DAS FLORES'), findsOneWidget);
      expect(find.text('VILA DO SOL'), findsOneWidget);
      expect(find.text('TERMINAL CENTRAL → VILA DO SOL'), findsOneWidget);
      expect(find.text('Ver parada no mapa'), findsNothing);
      expect(find.textContaining('Previsão'), findsNothing);
      expect(find.textContaining(' min'), findsNothing);
    });

    testWidgets('mostra a distância quando a localização está disponível', (
      tester,
    ) async {
      final repository = _FakeDetailsBusStopRepository(
        busStop: _busStop,
        busStopLines: const [_line],
      );
      final locationRepository = _FakeUserLocationRepository();
      addTearDown(repository.dispose);
      addTearDown(locationRepository.dispose);

      await tester.pumpWidget(
        _app(repository, locationRepository: locationRepository),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('de você'), findsNothing);

      locationRepository.emitLocation(
        const UserCoordinates(latitude: -5.1, longitude: -42.8),
      );
      await tester.pumpAndSettle();

      expect(find.text('A 0 m de você'), findsOneWidget);
    });

    testWidgets('marca as linhas que já estão sendo acompanhadas', (
      tester,
    ) async {
      final repository = _FakeDetailsBusStopRepository(
        busStop: _busStop,
        busStopLines: const [_line, _otherLine],
      );
      final trackingRepository = _FakeTrackingRepository();
      addTearDown(repository.dispose);
      addTearDown(trackingRepository.dispose);

      await tester.pumpWidget(
        _app(repository, trackingRepository: trackingRepository),
      );
      await tester.pumpAndSettle();

      expect(find.text('Acompanhando no mapa'), findsNothing);

      trackingRepository.emit([_trackedLine('101')]);
      await tester.pumpAndSettle();

      expect(find.text('Acompanhando no mapa'), findsOneWidget);
    });

    testWidgets('mostra mensagem quando a parada não tem linhas', (
      tester,
    ) async {
      final repository = _FakeDetailsBusStopRepository(busStop: _busStop);
      addTearDown(repository.dispose);

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      expect(
        find.text('Nenhuma linha cadastrada para esta parada no momento.'),
        findsOneWidget,
      );
      expect(find.text('Linhas que passam aqui'), findsOneWidget);
    });

    testWidgets('mostra parada não encontrada', (tester) async {
      final repository = _FakeDetailsBusStopRepository();
      addTearDown(repository.dispose);

      await tester.pumpWidget(_app(repository, busStopCode: '9999'));
      await tester.pumpAndSettle();

      expect(find.text('Parada não encontrada'), findsOneWidget);
      expect(find.textContaining('9999'), findsOneWidget);
    });

    testWidgets('mostra erro e permite tentar novamente', (tester) async {
      final repository = _FakeDetailsBusStopRepository(
        error: StateError('falha'),
      );
      addTearDown(repository.dispose);

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível carregar a parada'), findsOneWidget);

      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(repository.loadedCodes, ['174', '174']);
      expect(find.text('Não foi possível carregar a parada'), findsOneWidget);
    });
  });
}
