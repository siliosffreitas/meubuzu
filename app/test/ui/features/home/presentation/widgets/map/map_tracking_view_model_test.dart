import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/domain/models/route.dart';
import 'package:meubuzu/domain/models/tracked_line.dart';
import 'package:meubuzu/domain/models/user_coordinates.dart';
import 'package:meubuzu/domain/repositories/tracking_repository.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_tracking_state.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_tracking_view_model.dart';

const _line = Line(
  name: 'MOCAMBINHO DUQUE DE CAXIAS',
  origin: 'MOCAMBINHO',
  destination: 'MOCAMBINHO',
  boardingCode: '0301',
);
final _trackedLine = TrackedLine(
  line: _line,
  route: Route(
    positions: const [
      UserCoordinates(latitude: -5.1, longitude: -42.8),
      UserCoordinates(latitude: -5.2, longitude: -42.9),
    ],
  ),
  busPositions: const [],
);

class _FakeTrackingRepository implements TrackingRepository {
  _FakeTrackingRepository({
    this.trackedLine,
    this.error,
    this.changeShouldFail = false,
  });

  final TrackedLine? trackedLine;
  final Object? error;
  final _controller = StreamController<List<TrackedLine>>.broadcast();

  final started = <String>[];
  final stopped = <String>[];
  final changedCodes = <String>[];
  final changedValues = <int>[];
  bool changeShouldFail = false;
  bool isDisposed = false;

  @override
  Stream<List<TrackedLine>> get trackingRoutes => _controller.stream;

  void emit(List<TrackedLine> routes) => _controller.add(routes);

  void emitError(Object error) => _controller.addError(error);

  @override
  Future<TrackedLine?> startTracking(String lineCode) async {
    started.add(lineCode);
    final error = this.error;
    if (error != null) {
      throw error;
    }
    final tracked = trackedLine;
    if (tracked != null) {
      emit([tracked]);
    }
    return tracked;
  }

  @override
  Future<TrackedLine?> changeDirection(String lineCode, int direction) async {
    changedCodes.add(lineCode);
    changedValues.add(direction);
    if (changeShouldFail) {
      return null;
    }
    final tracked = trackedLine;
    if (tracked != null) {
      emit([tracked]);
    }
    return tracked;
  }

  @override
  Future<void> stopTracking(String lineCode) async {
    stopped.add(lineCode);
    emit(const []);
  }

  @override
  void dispose() {
    isDisposed = true;
    _controller.close();
  }
}

void main() {
  group('MapTrackingViewModel', () {
    test('começa ocioso', () async {
      final repository = _FakeTrackingRepository();
      final viewModel = MapTrackingViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      await pumpEventQueue();

      expect(viewModel.state, isA<MapTrackingIdle>());
      expect(viewModel.trackedLines, isEmpty);
      expect(viewModel.state.hasRoutes, isFalse);
      expect(viewModel.updatedAt, isNull);
      expect(viewModel.hasTrackedLines, isFalse);
      expect(viewModel.trackedLineCount, 0);
    });

    test('acompanha a linha e expõe o traçado', () async {
      final repository = _FakeTrackingRepository(trackedLine: _trackedLine);
      final viewModel = MapTrackingViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      final success = await viewModel.startTracking(' 0301 ');
      await pumpEventQueue();

      expect(success, isTrue);
      expect(repository.started, ['0301']);
      expect(viewModel.state, isA<MapTrackingReady>());
      expect(viewModel.trackedLines, [_trackedLine]);
      expect(viewModel.state.hasRoutes, isTrue);
      expect(viewModel.updatedAt, isNotNull);
      expect(viewModel.hasTrackedLines, isTrue);
      expect(viewModel.trackedLineCount, 1);
    });

    test('emite carregamento enquanto busca o traçado', () async {
      final repository = _FakeTrackingRepository(trackedLine: _trackedLine);
      final viewModel = MapTrackingViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      final states = <MapTrackingState>[];
      viewModel.addListener(() => states.add(viewModel.state));

      final future = viewModel.startTracking('0301');
      expect(viewModel.state, isA<MapTrackingLoading>());
      expect(viewModel.state.isLoading, isTrue);

      await future;
      await pumpEventQueue();

      expect(states.first, isA<MapTrackingLoading>());
      expect(states.last, isA<MapTrackingReady>());
    });

    test('linha não encontrada gera estado de erro', () async {
      final repository = _FakeTrackingRepository();
      final viewModel = MapTrackingViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      final success = await viewModel.startTracking('9999');
      await pumpEventQueue();

      expect(success, isFalse);
      expect(viewModel.state, isA<MapTrackingError>());
      expect(viewModel.state.errorMessage, contains('9999'));
    });

    test('falha do repositório gera estado de erro', () async {
      final repository = _FakeTrackingRepository(
        error: StateError('falha ao carregar'),
      );
      final viewModel = MapTrackingViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      final success = await viewModel.startTracking('0301');
      await pumpEventQueue();

      expect(success, isFalse);
      expect(viewModel.state, isA<MapTrackingError>());
    });

    test('código vazio não consulta o repositório', () async {
      final repository = _FakeTrackingRepository();
      final viewModel = MapTrackingViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      final success = await viewModel.startTracking('   ');

      expect(success, isFalse);
      expect(repository.started, isEmpty);
      expect(viewModel.state, isA<MapTrackingIdle>());
    });

    test('stream do repositório atualiza as linhas acompanhadas', () async {
      final repository = _FakeTrackingRepository();
      final viewModel = MapTrackingViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      repository.emit([_trackedLine]);
      await pumpEventQueue();

      expect(viewModel.state, isA<MapTrackingReady>());
      expect(viewModel.trackedLines, [_trackedLine]);
      expect(viewModel.updatedAt, isNotNull);
      expect(viewModel.trackedLineCount, 1);

      repository.emit(const []);
      await pumpEventQueue();

      expect(viewModel.state, isA<MapTrackingIdle>());
      expect(viewModel.trackedLines, isEmpty);
      expect(viewModel.updatedAt, isNull);
      expect(viewModel.hasTrackedLines, isFalse);
    });

    test('erro no stream gera estado de erro', () async {
      final repository = _FakeTrackingRepository();
      final viewModel = MapTrackingViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      repository.emitError(StateError('falha no stream'));
      await pumpEventQueue();

      expect(viewModel.state, isA<MapTrackingError>());
    });

    test('troca o sentido pelo repositório', () async {
      final repository = _FakeTrackingRepository(trackedLine: _trackedLine);
      final viewModel = MapTrackingViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      final success = await viewModel.changeDirection(' 0301 ', 1);

      expect(success, isTrue);
      expect(repository.changedCodes, ['0301']);
      expect(repository.changedValues, [1]);
      expect(viewModel.trackedLines, [_trackedLine]);
    });

    test('falha na troca mantém o estado anterior', () async {
      final repository = _FakeTrackingRepository(
        trackedLine: _trackedLine,
        changeShouldFail: true,
      );
      final viewModel = MapTrackingViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      repository.emit([_trackedLine]);
      await pumpEventQueue();

      final success = await viewModel.changeDirection('0301', 1);

      expect(success, isFalse);
      expect(viewModel.trackedLines, [_trackedLine]);
      expect(viewModel.state, isA<MapTrackingReady>());
    });

    test('encerra o acompanhamento pelo repositório', () async {
      final repository = _FakeTrackingRepository();
      final viewModel = MapTrackingViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      await viewModel.stopTracking(' 0301 ');
      await pumpEventQueue();

      expect(repository.stopped, ['0301']);
    });
  });
}
