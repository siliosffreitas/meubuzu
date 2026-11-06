import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/data/models/bus_stop.dart';
import 'package:meubuzu/data/models/line.dart';
import 'package:meubuzu/data/models/place_suggestion.dart';
import 'package:meubuzu/data/models/user_coordinates.dart';
import 'package:meubuzu/data/repositories/asset_place_search_repository.dart';
import 'package:meubuzu/data/services/bus_stop_service.dart';
import 'package:meubuzu/data/services/line_search_service.dart';

class _FakeLineSearchService implements LineSearchService {
  _FakeLineSearchService(this.lines);

  final List<Line> lines;
  final queries = <String>[];

  @override
  Future<List<Line>> search(String query) async {
    queries.add(query);
    return lines;
  }
}

class _FakeBusStopService implements BusStopService {
  _FakeBusStopService(this.stops);

  final List<BusStop> stops;
  final queries = <String>[];

  @override
  Future<List<BusStop>> findNearby(
    UserCoordinates position, {
    double maxDistanceInMeters = 500,
  }) async {
    return stops;
  }

  @override
  Future<List<BusStop>> search(String query) async {
    queries.add(query);
    return stops;
  }
}

void main() {
  group('AssetPlaceSearchRepository', () {
    final line = Line(
      id: '46',
      name: 'MOCAMBINHO DUQUE DE CAXIAS',
      origin: 'MOCAMBINHO',
      destination: 'MOCAMBINHO',
      boardingCode: '0301',
    );
    final stop = BusStop(
      id: '1',
      code: '2362',
      name: 'T-SANTA FÉ',
      address: 'Rua B, Loteamento Mário Covas',
      latitude: -5.165446,
      longitude: -42.791169,
    );

    test('retorna lista vazia para consulta sem texto', () async {
      final lineService = _FakeLineSearchService([]);
      final stopService = _FakeBusStopService([]);
      final repository = AssetPlaceSearchRepository(
        lineSearchService: lineService,
        busStopService: stopService,
      );

      final suggestions = await repository.search('   ');

      expect(suggestions, isEmpty);
      expect(lineService.queries, isEmpty);
      expect(stopService.queries, isEmpty);
    });

    test(
      'consulta as buscas de linhas e paradas e agrupa os resultados',
      () async {
        final lineService = _FakeLineSearchService([line]);
        final stopService = _FakeBusStopService([stop]);
        final repository = AssetPlaceSearchRepository(
          lineSearchService: lineService,
          busStopService: stopService,
        );

        final suggestions = await repository.search('875');

        expect(lineService.queries, ['875']);
        expect(stopService.queries, ['875']);
        expect(suggestions, hasLength(2));

        final lineSuggestion = suggestions.first;
        expect(lineSuggestion.type, PlaceSuggestionType.line);
        expect(lineSuggestion.id, '0301');
        expect(lineSuggestion.title, '0301');
        expect(lineSuggestion.subtitle, 'MOCAMBINHO DUQUE DE CAXIAS');
        expect(lineSuggestion.latitude, isNull);
        expect(lineSuggestion.longitude, isNull);

        final stopSuggestion = suggestions[1];
        expect(stopSuggestion.type, PlaceSuggestionType.stop);
        expect(stopSuggestion.id, '2362');
        expect(stopSuggestion.title, 'T-SANTA FÉ');
        expect(stopSuggestion.subtitle, 'Rua B, Loteamento Mário Covas');
        expect(stopSuggestion.latitude, -5.165446);
        expect(stopSuggestion.longitude, -42.791169);
      },
    );

    test('dispose libera os recursos do repositório', () {
      final repository = AssetPlaceSearchRepository(
        lineSearchService: _FakeLineSearchService([]),
        busStopService: _FakeBusStopService([]),
      );

      expect(repository, isNotNull);
      repository.dispose();
    });
  });
}
