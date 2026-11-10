import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/data/models/place_suggestion.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/domain/models/route.dart';
import 'package:meubuzu/domain/models/tracked_line.dart';
import 'package:meubuzu/domain/models/user_coordinates.dart';
import 'package:meubuzu/domain/repositories/place_search_repository.dart';
import 'package:meubuzu/domain/repositories/tracking_repository.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_search_cache.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_search_view_model.dart';

class _RecordingSearchRepository implements PlaceSearchRepository {
  @override
  void dispose() {}

  _RecordingSearchRepository(this.results);

  final List<PlaceSuggestion> results;
  final queries = <String>[];

  @override
  Future<List<PlaceSuggestion>> search(String query) async {
    queries.add(query);
    return results;
  }
}

class _FakeTrackingRepository implements TrackingRepository {
  final _controller = StreamController<List<TrackedLine>>.broadcast();

  void emit(List<TrackedLine> routes) => _controller.add(routes);

  void emitError(Object error) => _controller.addError(error);

  @override
  Stream<List<TrackedLine>> get trackingRoutes => _controller.stream;

  @override
  Future<TrackedLine?> startTracking(String lineCode) async => null;

  @override
  Future<void> stopTracking(String lineCode) async {}

  @override
  void dispose() => _controller.close();
}

final _trackedLine = TrackedLine(
  line: const Line(
    id: '46',
    name: 'MOCAMBINHO DUQUE DE CAXIAS',
    origin: 'MOCAMBINHO',
    destination: 'MOCAMBINHO',
    boardingCode: '101',
  ),
  route: Route(
    positions: const [UserCoordinates(latitude: -5.1, longitude: -42.8)],
  ),
  busPositions: const [],
);

const _line = PlaceSuggestion(
  id: '875A-10',
  code: '875A-10',
  type: PlaceSuggestionType.line,
  title: 'Perdizes ↔ Terminal Lapa',
  subtitle: 'Perdizes → Terminal Lapa',
  latitude: -23.537,
  longitude: -46.676,
);

void main() {
  group('MapSearchViewModel', () {
    test('começa vazio e sem resultados', () {
      final viewModel = MapSearchViewModel(_RecordingSearchRepository([]));
      addTearDown(viewModel.dispose);

      expect(viewModel.query, isEmpty);
      expect(viewModel.hasQuery, isFalse);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.results, isEmpty);
      expect(viewModel.showsResults, isFalse);
      expect(viewModel.trackedLineCodes, isEmpty);
      expect(viewModel.isLineTracked('101'), isFalse);
    });

    test('expõe as linhas já acompanhadas no mapa', () async {
      final trackingRepository = _FakeTrackingRepository();
      final viewModel = MapSearchViewModel(
        _RecordingSearchRepository([]),
        trackingRepository: trackingRepository,
      );
      addTearDown(viewModel.dispose);
      addTearDown(trackingRepository.dispose);

      trackingRepository.emit([_trackedLine]);
      await pumpEventQueue();

      expect(viewModel.trackedLineCodes, {'101'});
      expect(viewModel.isLineTracked(' 101 '), isTrue);
      expect(viewModel.isLineTracked('203'), isFalse);

      trackingRepository.emit(const []);
      await pumpEventQueue();

      expect(viewModel.trackedLineCodes, isEmpty);
      expect(viewModel.isLineTracked('101'), isFalse);
    });

    test('erro no rastreamento limpa as linhas acompanhadas', () async {
      final trackingRepository = _FakeTrackingRepository();
      final viewModel = MapSearchViewModel(
        _RecordingSearchRepository([]),
        trackingRepository: trackingRepository,
      );
      addTearDown(viewModel.dispose);
      addTearDown(trackingRepository.dispose);

      trackingRepository.emit([_trackedLine]);
      await pumpEventQueue();
      expect(viewModel.trackedLineCodes, {'101'});

      trackingRepository.emitError(StateError('falha no rastreamento'));
      await pumpEventQueue();

      expect(viewModel.trackedLineCodes, isEmpty);
    });

    testWidgets('busca após o debounce e expõe os resultados', (tester) async {
      final repository = _RecordingSearchRepository([_line]);
      final viewModel = MapSearchViewModel(repository);
      addTearDown(viewModel.dispose);

      viewModel
        ..setFocused(true)
        ..setQuery('875');

      expect(viewModel.isLoading, isTrue);
      expect(viewModel.showsResults, isTrue);
      expect(repository.queries, isEmpty);

      await tester.pump(const Duration(milliseconds: 400));

      expect(repository.queries, ['875']);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.results, [_line]);
    });

    testWidgets('descarta buscas anteriores ao digitar de novo', (
      tester,
    ) async {
      final repository = _RecordingSearchRepository([_line]);
      final viewModel = MapSearchViewModel(repository);
      addTearDown(viewModel.dispose);

      viewModel.setQuery('8');
      await tester.pump(const Duration(milliseconds: 100));
      viewModel.setQuery('875');
      await tester.pump(const Duration(milliseconds: 400));

      expect(repository.queries, ['875']);
      expect(viewModel.results, [_line]);
    });

    testWidgets('limpar volta ao estado inicial', (tester) async {
      final viewModel = MapSearchViewModel(_RecordingSearchRepository([_line]));
      addTearDown(viewModel.dispose);

      viewModel
        ..setFocused(true)
        ..setQuery('875');
      await tester.pump(const Duration(milliseconds: 400));

      viewModel.clear();

      expect(viewModel.query, isEmpty);
      expect(viewModel.hasQuery, isFalse);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.results, isEmpty);
      expect(viewModel.showsResults, isFalse);
    });

    test('sugestões ignoram acentos e maiúsculas', () {
      expect(_line.matches('875a'), isTrue);
      expect(_line.matches('lapa'), isTrue);
      expect(_line.matches('metro'), isFalse);
    });
  });

  group('cache da busca', () {
    test('restaura a última busca concluída', () {
      final cache = MapSearchCache()..save('875', const [_line]);
      final viewModel = MapSearchViewModel(
        _RecordingSearchRepository([]),
        cache: cache,
      );
      addTearDown(viewModel.dispose);

      expect(viewModel.query, '875');
      expect(viewModel.hasQuery, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.results, const [_line]);
    });

    testWidgets('salva a busca concluída no cache', (tester) async {
      final cache = MapSearchCache();
      final viewModel = MapSearchViewModel(
        _RecordingSearchRepository([_line]),
        cache: cache,
      );
      addTearDown(viewModel.dispose);

      viewModel.setQuery('875');
      await tester.pump(const Duration(milliseconds: 400));

      expect(cache.query, '875');
      expect(cache.results, [_line]);
    });

    testWidgets('não salva o texto de uma busca descartada', (tester) async {
      final cache = MapSearchCache();
      final repository = _RecordingSearchRepository([_line]);
      final viewModel = MapSearchViewModel(repository, cache: cache);
      addTearDown(viewModel.dispose);

      viewModel.setQuery('8');
      await tester.pump(const Duration(milliseconds: 100));
      viewModel.setQuery('875');
      await tester.pump(const Duration(milliseconds: 400));

      expect(repository.queries, ['875']);
      expect(cache.query, '875');
      expect(cache.results, [_line]);
    });

    testWidgets('limpar apaga a busca guardada', (tester) async {
      final cache = MapSearchCache();
      final viewModel = MapSearchViewModel(
        _RecordingSearchRepository([_line]),
        cache: cache,
      );
      addTearDown(viewModel.dispose);

      viewModel.setQuery('875');
      await tester.pump(const Duration(milliseconds: 400));
      expect(cache.query, '875');

      viewModel.clear();

      expect(cache.query, isEmpty);
      expect(cache.results, isEmpty);
    });

    test('pesquisa vazia apaga a busca guardada', () {
      final cache = MapSearchCache()..save('875', const [_line]);
      final viewModel = MapSearchViewModel(
        _RecordingSearchRepository([]),
        cache: cache,
      );
      addTearDown(viewModel.dispose);

      viewModel.setQuery('   ');

      expect(cache.query, isEmpty);
      expect(cache.results, isEmpty);
    });
  });
}
