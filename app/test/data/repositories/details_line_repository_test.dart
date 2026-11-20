import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/data/repositories/details_line_repository.dart';
import 'package:meubuzu/data/services/bus_stop_service.dart';
import 'package:meubuzu/data/services/line_search_service.dart';
import 'package:meubuzu/data/services/line_stops_service.dart';
import 'package:meubuzu/domain/models/bus_stop.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/domain/models/user_coordinates.dart';

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
              wanted.contains(line.boardingCode),
        )
        .toList();
  }
}

class _FakeLineStopsService implements LineStopsService {
  _FakeLineStopsService(this.codesByLine);

  final Map<String, List<String>> codesByLine;
  final queries = <String>[];

  @override
  Future<List<String>> findStopCodesForLine(String lineCode) async {
    queries.add(lineCode);
    return codesByLine[lineCode] ?? const [];
  }

  @override
  Future<List<String>> findLineCodesForStop(String stopCode) async {
    return const [];
  }
}

class _FakeBusStopService implements BusStopService {
  _FakeBusStopService(this.stops);

  final List<BusStop> stops;
  final codeQueries = <Iterable<String>>[];

  @override
  Future<List<BusStop>> findWithinBounds(
    UserCoordinates southwest,
    UserCoordinates northeast,
  ) async {
    return const [];
  }

  @override
  Future<List<BusStop>> search(String query) async {
    return const [];
  }

  @override
  Future<List<BusStop>> findByCodes(Iterable<String> codes) async {
    codeQueries.add(codes);
    final wanted = codes.toSet();
    return stops.where((stop) => wanted.contains(stop.code)).toList();
  }
}

void main() {
  const line = Line(
    name: 'MOCAMBINHO DUQUE DE CAXIAS',
    origin: 'MOCAMBINHO',
    destination: 'MOCAMBINHO',
    boardingCode: '0301',
  );
  const stop174 = BusStop(
    code: '174',
    name: 'PARADA 174',
    address: 'Rua A',
    latitude: -5.1,
    longitude: -42.8,
  );
  const stop175 = BusStop(
    code: '175',
    name: 'PARADA 175',
    address: 'Rua B',
    latitude: -5.2,
    longitude: -42.9,
  );

  group('DetailsLineRepositoryImpl', () {
    test('publica a linha e as paradas ao definir a linha', () async {
      final lineService = _FakeLineSearchService([line]);
      final lineStopsService = _FakeLineStopsService({
        '0301': ['174', '175'],
      });
      final busStopService = _FakeBusStopService([stop174, stop175]);
      final repository = DetailsLineRepositoryImpl(
        lineService,
        lineStopsService,
        busStopService,
      );

      final lineFuture = repository.currentLine.first;
      final stopsFuture = repository.busStops.first;

      await repository.setCurrentLine('0301');

      expect(await lineFuture, line);
      expect(await stopsFuture, [stop174, stop175]);
      expect(lineService.queries, ['0301']);
      expect(lineStopsService.queries, ['0301']);
      expect(busStopService.codeQueries.single, ['174', '175']);

      repository.dispose();
    });

    test('publica null e lista vazia para código vazio', () async {
      final lineService = _FakeLineSearchService([line]);
      final lineStopsService = _FakeLineStopsService({});
      final busStopService = _FakeBusStopService([stop174]);
      final repository = DetailsLineRepositoryImpl(
        lineService,
        lineStopsService,
        busStopService,
      );

      final lineFuture = repository.currentLine.first;
      final stopsFuture = repository.busStops.first;

      await repository.setCurrentLine('');

      expect(await lineFuture, isNull);
      expect(await stopsFuture, isEmpty);
      expect(lineService.queries, isEmpty);
      expect(lineStopsService.queries, isEmpty);

      repository.dispose();
    });

    test('publica null quando a linha não é encontrada', () async {
      final lineService = _FakeLineSearchService([]);
      final repository = DetailsLineRepositoryImpl(
        lineService,
        _FakeLineStopsService({}),
        _FakeBusStopService([]),
      );

      final lineFuture = repository.currentLine.first;

      await repository.setCurrentLine('9999');

      expect(await lineFuture, isNull);

      repository.dispose();
    });
  });
}
