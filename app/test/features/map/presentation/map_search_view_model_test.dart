import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/data/repositories/place_search_repository.dart';
import 'package:meubuzu/features/map/presentation/map_search_view_model.dart';

class _RecordingSearchRepository implements PlaceSearchRepository {
  _RecordingSearchRepository(this.results);

  final List<PlaceSuggestion> results;
  final queries = <String>[];

  @override
  Future<List<PlaceSuggestion>> search(String query) async {
    queries.add(query);
    return results;
  }
}

const _line = PlaceSuggestion(
  id: '875A-10',
  type: PlaceSuggestionType.line,
  title: '875A-10',
  subtitle: 'Perdizes ↔ Terminal Lapa',
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
}
