import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/data/repositories/details_bus_stop_repository.dart';
import 'package:meubuzu/data/services/bus_stop_service.dart';
import 'package:meubuzu/data/services/line_search_service.dart';
import 'package:meubuzu/data/services/line_stops_service.dart';
import 'package:meubuzu/domain/models/bus_stop.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/domain/models/user_coordinates.dart';

class _FakeBusStopService implements BusStopService {
  _FakeBusStopService(this.stops);

  final List<BusStop> stops;
  final codeQueries = <Iterable<String>>[];

  @override
  Future<List<BusStop>> findNearby(
    UserCoordinates position, {
    double maxDistanceInMeters = nearbyBusStopsRadiusInMeters,
  }) async {
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

class _FakeLineStopsService implements LineStopsService {
  _FakeLineStopsService(this.lineCodesByStop);

  final Map<String, List<String>> lineCodesByStop;
  final stopQueries = <String>[];

  @override
  Future<List<String>> findStopCodesForLine(String lineCode) async {
    return const [];
  }

  @override
  Future<List<String>> findLineCodesForStop(String stopCode) async {
    stopQueries.add(stopCode);
    return lineCodesByStop[stopCode] ?? const [];
  }
}

class _FakeLineSearchService implements LineSearchService {
  _FakeLineSearchService(this.lines);

  final List<Line> lines;
  final codeQueries = <Iterable<String>>[];

  @override
  Future<List<Line>> search(String query) async {
    return const [];
  }

  @override
  Future<List<Line>> findByCodes(Iterable<String> codes) async {
    codeQueries.add(codes);
    final wanted = codes.toSet();
    return lines
        .where(
          (line) =>
              wanted.contains(line.id) || wanted.contains(line.boardingCode),
        )
        .toList();
  }
}

void main() {
  const stop = BusStop(
    id: '1',
    code: '174',
    name: 'PARADA 174',
    address: 'Rua A',
    latitude: -5.1,
    longitude: -42.8,
  );
  const line46 = Line(
    id: '46',
    name: 'MOCAMBINHO DUQUE DE CAXIAS',
    origin: 'MOCAMBINHO',
    destination: 'MOCAMBINHO',
    boardingCode: '0301',
  );
  const line8000 = Line(
    id: '8000',
    name: 'VILA BANDEIRANTE',
    origin: 'VILA BANDEIRANTE',
    destination: 'VILA BANDEIRANTE',
    boardingCode: '0402',
  );

  group('DetailsBusStopRepositoryImpl', () {
    test(
      'publica a parada e as linhas ordenadas pelo código exibido',
      () async {
        final busStopService = _FakeBusStopService([stop]);
        final lineStopsService = _FakeLineStopsService({
          '174': ['0402', '0301'],
        });
        final lineSearchService = _FakeLineSearchService([line8000, line46]);
        final repository = DetailsBusStopRepositoryImpl(
          busStopService,
          lineStopsService,
          lineSearchService,
        );

        final stopFuture = repository.currentBusStop.first;
        final linesFuture = repository.lines.first;

        await repository.setCurrentBusStop('174');

        expect(await stopFuture, stop);
        expect(await linesFuture, [line46, line8000]);
        expect(busStopService.codeQueries.single, ['174']);
        expect(lineStopsService.stopQueries, ['174']);
        expect(lineSearchService.codeQueries.single, ['0402', '0301']);

        repository.dispose();
      },
    );

    test('publica null e lista vazia para código vazio', () async {
      final busStopService = _FakeBusStopService([stop]);
      final lineStopsService = _FakeLineStopsService({});
      final lineSearchService = _FakeLineSearchService([line46]);
      final repository = DetailsBusStopRepositoryImpl(
        busStopService,
        lineStopsService,
        lineSearchService,
      );

      final stopFuture = repository.currentBusStop.first;
      final linesFuture = repository.lines.first;

      await repository.setCurrentBusStop('   ');

      expect(await stopFuture, isNull);
      expect(await linesFuture, isEmpty);
      expect(busStopService.codeQueries, isEmpty);
      expect(lineStopsService.stopQueries, isEmpty);
      expect(lineSearchService.codeQueries, isEmpty);

      repository.dispose();
    });

    test(
      'publica null e lista vazia quando a parada não é encontrada',
      () async {
        final lineStopsService = _FakeLineStopsService({});
        final repository = DetailsBusStopRepositoryImpl(
          _FakeBusStopService([]),
          lineStopsService,
          _FakeLineSearchService([line46]),
        );

        final stopFuture = repository.currentBusStop.first;
        final linesFuture = repository.lines.first;

        await repository.setCurrentBusStop('9999');

        expect(await stopFuture, isNull);
        expect(await linesFuture, isEmpty);
        expect(lineStopsService.stopQueries, isEmpty);

        repository.dispose();
      },
    );

    test('publica lista vazia quando nenhuma linha é encontrada', () async {
      final lineSearchService = _FakeLineSearchService([]);
      final repository = DetailsBusStopRepositoryImpl(
        _FakeBusStopService([stop]),
        _FakeLineStopsService({
          '174': ['0301'],
        }),
        lineSearchService,
      );

      final stopFuture = repository.currentBusStop.first;
      final linesFuture = repository.lines.first;

      await repository.setCurrentBusStop('174');

      expect(await stopFuture, stop);
      expect(await linesFuture, isEmpty);
      expect(lineSearchService.codeQueries.single, ['0301']);

      repository.dispose();
    });

    test('dispose encerra os streams', () async {
      final repository = DetailsBusStopRepositoryImpl(
        _FakeBusStopService([]),
        _FakeLineStopsService({}),
        _FakeLineSearchService([]),
      );

      final stopDone = expectLater(repository.currentBusStop, emitsDone);
      final linesDone = expectLater(repository.lines, emitsDone);

      repository.dispose();

      await stopDone;
      await linesDone;
    });
  });
}
