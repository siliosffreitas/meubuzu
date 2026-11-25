import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/domain/models/bus_stop.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/domain/models/tracked_line.dart';
import 'package:meubuzu/domain/models/user_coordinates.dart';
import 'package:meubuzu/domain/repositories/details_bus_stop_repository.dart';
import 'package:meubuzu/domain/repositories/tracking_repository.dart';
import 'package:meubuzu/domain/repositories/user_location_repository.dart';
import 'package:meubuzu/ui/features/bus_stop_details/presentation/details_bus_stop_state.dart';
import 'package:meubuzu/ui/features/bus_stop_details/presentation/details_bus_stop_view_model.dart';

const _busStop = BusStop(
  code: '174',
  name: 'PRAÇA DO IPÊ',
  address: 'Rua do Mercado, 180',
  latitude: -5.1,
  longitude: -42.8,
);

const _line = Line(
  name: 'MOCAMBINHO DUQUE DE CAXIAS',
  origin: 'MOCAMBINHO',
  destination: 'MOCAMBINHO',
  boardingCode: '0301',
);

class _FakeDetailsBusStopRepository implements DetailsBusStopRepository {
  BusStop? busStop;
  List<Line> busStopLines = const [];
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
  final _visibleStopsController = StreamController<List<BusStop>>.broadcast();

  void emitLocation(UserCoordinates position) {
    _locationController.add(position);
  }

  void emitError(Object error) {
    _locationController.addError(error);
  }

  @override
  Stream<UserCoordinates> get location => _locationController.stream;

  @override
  Stream<List<BusStop>> get visibleStops => _visibleStopsController.stream;

  @override
  Future<void> refresh({bool requestPermission = true}) async {}

  @override
  Future<void> updateVisibleArea({
    required UserCoordinates southwest,
    required UserCoordinates northeast,
  }) async {}

  @override
  void clearVisibleStops() {}

  @override
  Future<void> openLocationSettings() async {}

  @override
  Future<void> openAppSettings() async {}

  @override
  void dispose() {
    _locationController.close();
    _visibleStopsController.close();
  }
}

class _FakeTrackingRepository implements TrackingRepository {
  final _controller = StreamController<List<TrackedLine>>.broadcast();

  void emit(List<TrackedLine> lines) => _controller.add(lines);

  void emitError(Object error) => _controller.addError(error);

  @override
  Stream<List<TrackedLine>> get trackingRoutes => _controller.stream;

  @override
  Future<TrackedLine?> startTracking(String lineCode) async => null;

  @override
  Future<TrackedLine?> changeDirection(String lineCode, int direction) async =>
      null;

  @override
  Future<void> stopTracking(String lineCode) async {}

  @override
  void dispose() => _controller.close();
}

TrackedLine _trackedLine(String code) {
  return TrackedLine(
    line: Line(
      // O rastreamento usa o `sgLinha`; o `id` é o código interno do catálogo.
      name: 'MOCAMBINHO DUQUE DE CAXIAS',
      origin: 'MOCAMBINHO',
      destination: 'MOCAMBINHO',
      boardingCode: code,
    ),
    route: null,
    busPositions: const [],
  );
}

void main() {
  group('DetailsBusStopViewModel', () {
    late _FakeDetailsBusStopRepository repository;

    setUp(() {
      repository = _FakeDetailsBusStopRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    DetailsBusStopViewModel createViewModel({
      String busStopCode = '174',
      UserLocationRepository? locationRepository,
      TrackingRepository? trackingRepository,
    }) {
      return DetailsBusStopViewModel(
        repository,
        busStopCode: busStopCode,
        locationRepository: locationRepository,
        trackingRepository: trackingRepository,
      );
    }

    test('inicia no estado ocioso e sem distância', () {
      final viewModel = createViewModel();
      addTearDown(viewModel.dispose);

      expect(viewModel.state, isA<DetailsBusStopIdle>());
      expect(viewModel.busStopCode, '174');
      expect(viewModel.distanceInMeters, isNull);
    });

    test('carrega a parada e publica as linhas', () async {
      repository
        ..busStop = _busStop
        ..busStopLines = const [_line];
      final viewModel = createViewModel();
      addTearDown(viewModel.dispose);

      final states = <DetailsBusStopState>[];
      viewModel.addListener(() => states.add(viewModel.state));

      final loading = viewModel.load();
      expect(viewModel.state, isA<DetailsBusStopLoading>());

      await loading;
      await pumpEventQueue();

      expect(repository.loadedCodes, ['174']);
      expect(viewModel.state, isA<DetailsBusStopReady>());

      final state = viewModel.state as DetailsBusStopReady;
      expect(state.busStop, _busStop);
      expect(state.lines, [_line]);
      expect(states.first, isA<DetailsBusStopLoading>());
    });

    test('publica não encontrada quando a parada não existe', () async {
      final viewModel = createViewModel(busStopCode: '9999');
      addTearDown(viewModel.dispose);

      await viewModel.load();
      await pumpEventQueue();

      expect(viewModel.state, isA<DetailsBusStopNotFound>());
    });

    test('publica sucesso mesmo sem linhas', () async {
      repository.busStop = _busStop;
      final viewModel = createViewModel();
      addTearDown(viewModel.dispose);

      await viewModel.load();
      await pumpEventQueue();

      final state = viewModel.state;
      expect(state, isA<DetailsBusStopReady>());
      expect((state as DetailsBusStopReady).busStop, _busStop);
      expect(state.lines, isEmpty);
    });

    test('publica erro quando o repositório falha', () async {
      repository.error = StateError('falha');
      final viewModel = createViewModel();
      addTearDown(viewModel.dispose);

      await viewModel.load();
      await pumpEventQueue();

      expect(viewModel.state, isA<DetailsBusStopError>());
    });

    test('calcula a distância quando a localização é publicada', () async {
      repository.busStop = _busStop;
      final locationRepository = _FakeUserLocationRepository();
      addTearDown(locationRepository.dispose);
      final viewModel = createViewModel(locationRepository: locationRepository);
      addTearDown(viewModel.dispose);

      await viewModel.load();
      await pumpEventQueue();
      expect(viewModel.distanceInMeters, isNull);

      locationRepository.emitLocation(
        const UserCoordinates(latitude: -5.1, longitude: -42.8),
      );
      await pumpEventQueue();

      expect(viewModel.distanceInMeters, closeTo(0, 0.001));
    });

    test('erro de localização mantém a tela sem distância', () async {
      repository.busStop = _busStop;
      final locationRepository = _FakeUserLocationRepository();
      addTearDown(locationRepository.dispose);
      final viewModel = createViewModel(locationRepository: locationRepository);
      addTearDown(viewModel.dispose);

      await viewModel.load();
      await pumpEventQueue();

      locationRepository.emitError(StateError('sem GPS'));
      await pumpEventQueue();

      expect(viewModel.state, isA<DetailsBusStopReady>());
      expect(viewModel.distanceInMeters, isNull);
    });

    test('reconhece a linha acompanhada pelo sgLinha', () async {
      repository.busStop = _busStop;
      final trackingRepository = _FakeTrackingRepository();
      addTearDown(trackingRepository.dispose);
      final viewModel = createViewModel(trackingRepository: trackingRepository);
      addTearDown(viewModel.dispose);

      await viewModel.load();
      await pumpEventQueue();

      trackingRepository.emit([_trackedLine('0301')]);
      await pumpEventQueue();

      expect(viewModel.trackedLineCodes, {'0301'});
    });

    test('ignora linha acompanhada sem sgLinha', () async {
      final trackingRepository = _FakeTrackingRepository();
      addTearDown(trackingRepository.dispose);
      final viewModel = createViewModel(trackingRepository: trackingRepository);
      addTearDown(viewModel.dispose);

      final tracked = TrackedLine(
        line: const Line(
          name: 'SEM SG',
          origin: '',
          destination: '',
          boardingCode: '',
        ),
        route: null,
        busPositions: const [],
      );

      trackingRepository.emit([tracked]);
      await pumpEventQueue();

      expect(viewModel.trackedLineCodes, isEmpty);
    });

    test('limpa as linhas acompanhadas quando o rastreamento falha', () async {
      final trackingRepository = _FakeTrackingRepository();
      addTearDown(trackingRepository.dispose);
      final viewModel = createViewModel(trackingRepository: trackingRepository);
      addTearDown(viewModel.dispose);

      trackingRepository.emit([_trackedLine('0301')]);
      await pumpEventQueue();
      expect(viewModel.trackedLineCodes, {'0301'});

      trackingRepository.emitError(StateError('sem conexão'));
      await pumpEventQueue();

      expect(viewModel.trackedLineCodes, isEmpty);
    });
  });
}
