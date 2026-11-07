import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/domain/models/bus_stop.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/domain/repositories/details_line_repository.dart';
import 'package:meubuzu/ui/features/line_details/presentation/details_line_state.dart';
import 'package:meubuzu/ui/features/line_details/presentation/details_line_view_model.dart';

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

    setUp(() {
      repository = _FakeDetailsLineRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    test('inicia no estado ocioso', () {
      final viewModel = DetailsLineViewModel(repository, lineCode: '0301');
      addTearDown(viewModel.dispose);

      expect(viewModel.state, isA<DetailsLineIdle>());
      expect(viewModel.lineCode, '0301');
    });

    test('carrega a linha e publica as paradas em ordem', () async {
      repository
        ..line = _line
        ..stops = const [_firstStop, _secondStop];
      final viewModel = DetailsLineViewModel(repository, lineCode: '0301');
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
      final viewModel = DetailsLineViewModel(repository, lineCode: '0301');
      addTearDown(viewModel.dispose);

      await viewModel.load();
      await pumpEventQueue();

      expect(viewModel.state, isA<DetailsLineNoStops>());
      expect((viewModel.state as DetailsLineNoStops).line, _line);
    });

    test('linha inexistente gera o estado de não encontrada', () async {
      repository.line = null;
      final viewModel = DetailsLineViewModel(repository, lineCode: '9999');
      addTearDown(viewModel.dispose);

      await viewModel.load();
      await pumpEventQueue();

      expect(viewModel.state, isA<DetailsLineNotFound>());
      expect(repository.loadedCodes, ['9999']);
    });

    test('erro ao carregar gera o estado de erro', () async {
      repository.error = StateError('catálogo indisponível');
      final viewModel = DetailsLineViewModel(repository, lineCode: '0301');
      addTearDown(viewModel.dispose);

      await viewModel.load();
      await pumpEventQueue();

      expect(viewModel.state, isA<DetailsLineError>());
    });

    test('tentar novamente recarrega a linha', () async {
      repository.error = StateError('catálogo indisponível');
      final viewModel = DetailsLineViewModel(repository, lineCode: '0301');
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
  });
}
