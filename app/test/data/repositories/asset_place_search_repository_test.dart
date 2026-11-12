import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/domain/models/bus_stop.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/data/models/place_suggestion.dart';
import 'package:meubuzu/domain/models/user_coordinates.dart';
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

  @override
  Future<List<Line>> findByCodes(Iterable<String> codes) async {
    final wanted = codes.toSet();
    return lines
        .where(
          (line) =>
              wanted.contains(line.id) || wanted.contains(line.boardingCode),
        )
        .toList();
  }
}

class _FakeBusStopService implements BusStopService {
  _FakeBusStopService(this.stops);

  final List<BusStop> stops;
  final queries = <String>[];

  @override
  Future<List<BusStop>> findWithinBounds(
    UserCoordinates southwest,
    UserCoordinates northeast,
  ) async {
    return stops;
  }

  @override
  Future<List<BusStop>> search(String query) async {
    queries.add(query);
    return stops;
  }

  @override
  Future<List<BusStop>> findByCodes(Iterable<String> codes) async {
    final wanted = codes.toSet();
    return stops.where((stop) => wanted.contains(stop.code)).toList();
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
        expect(lineSuggestion.id, '46');
        expect(lineSuggestion.code, '0301');
        expect(lineSuggestion.title, 'MOCAMBINHO DUQUE DE CAXIAS');
        expect(lineSuggestion.subtitle, 'Circular • MOCAMBINHO');
        expect(lineSuggestion.latitude, isNull);
        expect(lineSuggestion.longitude, isNull);

        final stopSuggestion = suggestions[1];
        expect(stopSuggestion.type, PlaceSuggestionType.stop);
        expect(stopSuggestion.id, '2362');
        expect(stopSuggestion.code, '2362');
        expect(stopSuggestion.title, 'T-SANTA FÉ');
        expect(stopSuggestion.subtitle, 'Rua B, Loteamento Mário Covas');
        expect(stopSuggestion.latitude, -5.165446);
        expect(stopSuggestion.longitude, -42.791169);
      },
    );

    test('monta o trajeto quando origem e destino são diferentes', () async {
      const line = Line(
        id: '1',
        name: 'CENTRO / SHOPPING',
        origin: 'CENTRO',
        destination: 'SHOPPING',
        boardingCode: '0101',
      );
      final repository = AssetPlaceSearchRepository(
        lineSearchService: _FakeLineSearchService([line]),
        busStopService: _FakeBusStopService([]),
      );

      final suggestions = await repository.search('centro');

      expect(suggestions.single.code, '0101');
      expect(suggestions.single.subtitle, 'CENTRO → SHOPPING');
    });

    test('usa o código da linha quando não há código de embarque', () async {
      const line = Line(
        id: '408',
        name: 'BELAVISTA VIA S.MARIA',
        origin: 'TERMINAL 1',
        destination: 'TERMINAL 1',
        boardingCode: null,
      );
      final repository = AssetPlaceSearchRepository(
        lineSearchService: _FakeLineSearchService([line]),
        busStopService: _FakeBusStopService([]),
      );

      final suggestions = await repository.search('belavista');

      expect(suggestions.single.code, '408');
    });

    test('ordena as linhas pelo sgLinha', () async {
      const lines = [
        Line(
          id: '46',
          name: 'MOCAMBINHO DUQUE DE CAXIAS',
          origin: 'MOCAMBINHO',
          destination: 'MOCAMBINHO',
          boardingCode: '0301',
        ),
        Line(
          id: '1',
          name: 'CENTRO / SHOPPING',
          origin: 'CENTRO',
          destination: 'SHOPPING',
          boardingCode: '0101',
        ),
        Line(
          id: '10',
          name: 'TERMINAL / UNIVERSIDADE',
          origin: 'TERMINAL',
          destination: 'UNIVERSIDADE',
          boardingCode: 'T0100',
        ),
      ];
      final repository = AssetPlaceSearchRepository(
        lineSearchService: _FakeLineSearchService(lines),
        busStopService: _FakeBusStopService([]),
      );

      final suggestions = await repository.search('terminal');

      expect(suggestions.map((suggestion) => suggestion.code), [
        '0101',
        '0301',
        'T0100',
      ]);
    });

    test('ordena usando o código interno quando não há sgLinha', () async {
      const lines = [
        Line(
          id: '408',
          name: 'BELAVISTA VIA S.MARIA',
          origin: 'TERMINAL 1',
          destination: 'TERMINAL 1',
          boardingCode: null,
        ),
        Line(
          id: '205',
          name: 'CENTRO / SHOPPING',
          origin: 'CENTRO',
          destination: 'SHOPPING',
          boardingCode: null,
        ),
      ];
      final repository = AssetPlaceSearchRepository(
        lineSearchService: _FakeLineSearchService(lines),
        busStopService: _FakeBusStopService([]),
      );

      final suggestions = await repository.search('centro');

      expect(suggestions.map((suggestion) => suggestion.code), ['205', '408']);
    });

    test('desempata linhas de mesmo sgLinha pelo nome', () async {
      const lines = [
        Line(
          id: '2',
          name: 'ZONA SUL',
          origin: 'A',
          destination: 'B',
          boardingCode: '0501',
        ),
        Line(
          id: '1',
          name: 'ZONA NORTE',
          origin: 'A',
          destination: 'B',
          boardingCode: '0501',
        ),
      ];
      final repository = AssetPlaceSearchRepository(
        lineSearchService: _FakeLineSearchService(lines),
        busStopService: _FakeBusStopService([]),
      );

      final suggestions = await repository.search('zona');

      expect(suggestions.map((suggestion) => suggestion.title), [
        'ZONA NORTE',
        'ZONA SUL',
      ]);
    });

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
