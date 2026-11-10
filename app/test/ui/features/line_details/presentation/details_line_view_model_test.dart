import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/domain/models/bus_stop.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/domain/repositories/details_line_repository.dart';
import 'package:meubuzu/ui/features/line_details/presentation/details_line_state.dart';
import 'package:meubuzu/ui/features/line_details/presentation/details_line_view_model.dart';

import '../../../../helpers/fake_tracking_repository.dart';

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
  name: 'PARADA 174',
  address: 'Rua A',
  latitude: -5.1,
  longitude: -42.8,
);

const _secondStop = BusStop(
  id: '2',
  code: '175',
  name: 'PARADA 175',
  address: 'Rua B',
  latitude: -5.2,
  longitude: -42.9,
);

class _FakeDetailsLineRepository implements DetailsLineRepository {
  Line? line;
  List<BusStop> stops = const [];
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

void main() {
  group('DetailsLineViewModel', () {
    late _FakeDetailsLineRepository repository;
    late FakeTrackingRepository trackingRepository;

    setUp(() {
      repository = _FakeDetailsLineRepository();
      trackingRepository = FakeTrackingRepository();
    });

    tearDown(() {
      repository.dispose();
      trackingRepository.dispose();
    });

    DetailsLineViewModel createViewModel({String lineCode = '0301'}) {
      return DetailsLineViewModel(
        repository,
        lineCode: lineCode,
        trackingRepository: trackingRepository,
      );
    }

    test('inicia no estado ocioso', () {
      final viewModel = createViewModel();
      addTearDown(viewModel.dispose);

      expect(viewModel.state, isA<DetailsLineIdle>());
      expect(viewModel.lineCode, '0301');
      expect(viewModel.isTracking, isFalse);
    });

    test('carrega a linha e publica as paradas em ordem', () async {
      repository
        ..line = _line
        ..stops = const [_firstStop, _secondStop];
      final viewModel = createViewModel();
      addTearDown(viewModel.dispose);

      final states = <DetailsLineState>[];
      viewModel.addListener(() => states.add(viewModel.state));

      final loading = viewModel.load();
      expect(viewModel.state, isA<DetailsLineLoading>());

      await loading;
      await pumpEventQueue();

      expect(repository.loadedCodes, ['0301']);
      expect(viewModel.state, isA<DetailsLineReady>());

      final state = viewModel.state as DetailsLineReady;
      expect(state.line, _line);
      expect(state.stops, const [_firstStop, _secondStop]);
      expect(states.first, isA<DetailsLineLoading>());
      expect(states.last, isA<DetailsLineReady>());
    });

    test('linha sem paradas gera o estado vazio', () async {
      repository
        ..line = _line
        ..stops = const [];
      final viewModel = createViewModel();
      addTearDown(viewModel.dispose);

      await viewModel.load();
      await pumpEventQueue();

      expect(viewModel.state, isA<DetailsLineNoStops>());
      expect((viewModel.state as DetailsLineNoStops).line, _line);
    });

    test('linha inexistente gera o estado de não encontrada', () async {
      repository.line = null;
      final viewModel = createViewModel(lineCode: '9999');
      addTearDown(viewModel.dispose);

      await viewModel.load();
      await pumpEventQueue();

      expect(viewModel.state, isA<DetailsLineNotFound>());
      expect(repository.loadedCodes, ['9999']);
    });

    test('erro ao carregar gera o estado de erro', () async {
      repository.error = StateError('catálogo indisponível');
      final viewModel = createViewModel();
      addTearDown(viewModel.dispose);

      await viewModel.load();
      await pumpEventQueue();

      expect(viewModel.state, isA<DetailsLineError>());
    });

    test('tentar novamente recarrega a linha', () async {
      repository.error = StateError('catálogo indisponível');
      final viewModel = createViewModel();
      addTearDown(viewModel.dispose);

      await viewModel.load();
      await pumpEventQueue();
      expect(viewModel.state, isA<DetailsLineError>());

      repository
        ..error = null
        ..line = _line
        ..stops = const [_firstStop];

      await viewModel.load();
      await pumpEventQueue();

      expect(viewModel.state, isA<DetailsLineReady>());
      expect(repository.loadedCodes, ['0301', '0301']);
    });

    test('fica acompanhada quando a linha entra no rastreamento', () async {
      repository
        ..line = _line
        ..stops = const [_firstStop];
      final viewModel = createViewModel();
      addTearDown(viewModel.dispose);
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      trackingRepository.emit([trackedLineFor(_line)]);
      await pumpEventQueue();

      expect(viewModel.isTracking, isTrue);
      expect(notifications, 1);

      // Emissões repetidas com o mesmo status não notificam de novo.
      trackingRepository.emit([trackedLineFor(_line)]);
      await pumpEventQueue();

      expect(viewModel.isTracking, isTrue);
      expect(notifications, 1);
    });

    test('reconhece a linha acompanhada pelo código interno', () async {
      const otherLine = Line(
        id: '46',
        name: 'MOCAMBINHO DUQUE DE CAXIAS',
        origin: 'MOCAMBINHO',
        destination: 'MOCAMBINHO',
        boardingCode: '9999',
      );
      final viewModel = createViewModel(lineCode: '46');
      addTearDown(viewModel.dispose);

      trackingRepository.emit([trackedLineFor(otherLine)]);
      await pumpEventQueue();

      expect(viewModel.isTracking, isTrue);
    });

    test('desmarca ao sair do rastreamento', () async {
      repository
        ..line = _line
        ..stops = const [_firstStop];
      final viewModel = createViewModel();
      addTearDown(viewModel.dispose);

      trackingRepository.emit([trackedLineFor(_line)]);
      await pumpEventQueue();
      expect(viewModel.isTracking, isTrue);

      trackingRepository.emit(const []);
      await pumpEventQueue();

      expect(viewModel.isTracking, isFalse);
    });

    test('remove a linha do mapa usando o código de embarque', () async {
      repository
        ..line = _line
        ..stops = const [_firstStop];
      final viewModel = createViewModel(lineCode: '46');
      addTearDown(viewModel.dispose);

      await viewModel.load();
      await pumpEventQueue();

      await viewModel.stopTracking();

      expect(trackingRepository.stoppedCodes, ['0301']);
    });
  });
}
