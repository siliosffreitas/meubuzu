import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/data/repositories/tracking_repository.dart';
import 'package:meubuzu/data/services/line_search_service.dart';
import 'package:meubuzu/data/services/route_service.dart';
import 'package:meubuzu/data/services/tracking_service.dart';
import 'package:meubuzu/domain/models/bus.dart';
import 'package:meubuzu/domain/models/bus_position.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/domain/models/route.dart';
import 'package:meubuzu/domain/models/tracked_line.dart';
import 'package:meubuzu/domain/models/user_coordinates.dart';

class _FakeLineSearchService implements LineSearchService {
  _FakeLineSearchService(this.lines);

  final List<Line> lines;
  final queries = <String>[];

  @override
  Future<List<Line>> search(String query) async {
    queries.add(query);
    return lines
        .where(
          (line) =>
              line.id == query || line.boardingCode?.trim() == query.trim(),
        )
        .toList(growable: false);
  }

  @override
  Future<List<Line>> findByCodes(Iterable<String> codes) async {
    final wanted = codes.toSet();
    return lines
        .where(
          (line) =>
              wanted.contains(line.id) || wanted.contains(line.boardingCode),
        )
        .toList(growable: false);
  }
}

class _FakeRouteService implements RouteService {
  _FakeRouteService(this.routes);

  final Map<String, Route?> routes;
  final queries = <String>[];

  @override
  Future<Route?> findRoute(String lineCode) async {
    queries.add(lineCode);
    return routes[lineCode];
  }
}

class _FakeTrackingService implements TrackingService {
  _FakeTrackingService(this.positions);

  List<BusPosition> positions;
  final queries = <List<Line>>[];
  bool shouldThrow = false;

  @override
  Future<List<BusPosition>> findPositions(
    List<Line> lines, {
    DateTime? at,
  }) async {
    queries.add(lines);
    if (shouldThrow) {
      throw StateError('falha na consulta de posições');
    }
    return positions;
  }
}

BusPosition _position(String busCode) {
  return BusPosition(
    bus: Bus(code: busCode),
    latitude: -5.102443,
    longitude: -42.727275,
    capturedAt: DateTime.utc(2023, 6, 4, 11, 58),
  );
}

void main() {
  const line = Line(
    id: '46',
    name: 'MOCAMBINHO DUQUE DE CAXIAS',
    origin: 'MOCAMBINHO',
    destination: 'MOCAMBINHO',
    boardingCode: '0301',
  );
  const otherLine = Line(
    id: '47',
    name: 'OUTRA LINHA',
    origin: 'CENTRO',
    destination: 'SHOPPING',
    boardingCode: '0302',
  );
  final route = Route(
    positions: const [
      UserCoordinates(latitude: -5.1, longitude: -42.8),
      UserCoordinates(latitude: -5.2, longitude: -42.9),
    ],
  );

  group('TrackingRepositoryImpl', () {
    test('publica a linha acompanhada com o traçado', () async {
      final lineService = _FakeLineSearchService([line]);
      final routeService = _FakeRouteService({'0301': route});
      final repository = TrackingRepositoryImpl(routeService, lineService);

      final routesFuture = repository.trackingRoutes.firstWhere(
        (routes) => routes.isNotEmpty,
      );

      final tracked = await repository.startTracking('0301');

      final routes = await routesFuture;
      expect(tracked, isNotNull);
      expect(tracked, same(routes.single));
      expect(routes, hasLength(1));
      expect(routes.single.line, line);
      expect(routes.single.route, route);
      expect(routes.single.busPositions, isEmpty);
      expect(lineService.queries, ['0301']);
      expect(routeService.queries, ['0301']);

      repository.dispose();
    });

    test('inclui as posições dos ônibus retornadas pelo serviço', () async {
      final trackingService = _FakeTrackingService([_position('4171')]);
      final repository = TrackingRepositoryImpl(
        _FakeRouteService({'0301': route}),
        _FakeLineSearchService([line]),
        trackingService: trackingService,
      );

      final tracked = await repository.startTracking('0301');

      expect(tracked, isNotNull);
      expect(tracked!.busPositions, hasLength(1));
      expect(tracked.busPositions.single.bus.code, '4171');
      expect(trackingService.queries.single, [line]);

      repository.dispose();
    });

    test('publica a linha mesmo quando o traçado não existe', () async {
      final repository = TrackingRepositoryImpl(
        _FakeRouteService({'0301': null}),
        _FakeLineSearchService([line]),
      );
      final routesFuture = repository.trackingRoutes.firstWhere(
        (routes) => routes.isNotEmpty,
      );

      await repository.startTracking('0301');

      final routes = await routesFuture;
      expect(routes.single.line, line);
      expect(routes.single.route, isNull);

      repository.dispose();
    });

    test('novo ouvinte recebe o estado atual', () async {
      final repository = TrackingRepositoryImpl(
        _FakeRouteService({'0301': route}),
        _FakeLineSearchService([line]),
      );

      await repository.startTracking('0301');
      final routes = await repository.trackingRoutes.first;

      expect(routes, hasLength(1));
      expect(routes.single.line, line);

      repository.dispose();
    });

    test('remove a linha ao encerrar o acompanhamento', () async {
      final repository = TrackingRepositoryImpl(
        _FakeRouteService({'0301': route}),
        _FakeLineSearchService([line]),
      );
      final emissions = <List<TrackedLine>>[];
      final subscription = repository.trackingRoutes.listen(emissions.add);

      await repository.startTracking('0301');
      await _flushStream();
      await repository.stopTracking('0301');
      await _flushStream();

      expect(emissions.first, isEmpty);
      expect(emissions.last, isEmpty);
      expect(emissions.any((routes) => routes.isNotEmpty), isTrue);

      await subscription.cancel();
      repository.dispose();
    });

    test('não duplica uma linha já acompanhada', () async {
      final routeService = _FakeRouteService({'0301': route});
      final repository = TrackingRepositoryImpl(
        routeService,
        _FakeLineSearchService([line]),
      );
      final emissions = <List<TrackedLine>>[];
      final subscription = repository.trackingRoutes.listen(emissions.add);

      await repository.startTracking('0301');
      await repository.startTracking('0301');
      await _flushStream();

      expect(emissions.last, hasLength(1));
      expect(routeService.queries, ['0301']);

      await subscription.cancel();
      repository.dispose();
    });

    test('não publica linha inexistente no catálogo', () async {
      final routeService = _FakeRouteService({});
      final repository = TrackingRepositoryImpl(
        routeService,
        _FakeLineSearchService([]),
      );
      final emissions = <List<TrackedLine>>[];
      final subscription = repository.trackingRoutes.listen(emissions.add);

      await repository.startTracking('9999');
      await _flushStream();

      expect(emissions.every((routes) => routes.isEmpty), isTrue);
      expect(routeService.queries, isEmpty);

      await subscription.cancel();
      repository.dispose();
    });

    test('retorna a linha já acompanhada sem recarregar o traçado', () async {
      final routeService = _FakeRouteService({'0301': route});
      final repository = TrackingRepositoryImpl(
        routeService,
        _FakeLineSearchService([line]),
      );
      addTearDown(repository.dispose);

      final first = await repository.startTracking('0301');
      final second = await repository.startTracking('0301');

      expect(second, same(first));
      expect(routeService.queries, ['0301']);
    });

    test('código vazio não consulta as dependências', () async {
      final lineService = _FakeLineSearchService([line]);
      final routeService = _FakeRouteService({});
      final repository = TrackingRepositoryImpl(routeService, lineService);

      await repository.startTracking('   ');

      expect(lineService.queries, isEmpty);
      expect(routeService.queries, isEmpty);

      repository.dispose();
    });

    test('encerra o stream ao descartar o repositório', () async {
      final repository = TrackingRepositoryImpl(
        _FakeRouteService({}),
        _FakeLineSearchService([]),
      );

      final done = expectLater(
        repository.trackingRoutes,
        emitsInOrder([isEmpty, emitsDone]),
      );

      repository.dispose();

      await done;
    });

    test('consulta as linhas já acompanhadas ao adicionar uma nova', () async {
      final trackingService = _FakeTrackingService([_position('4171')]);
      final repository = TrackingRepositoryImpl(
        _FakeRouteService({'0301': route, '0302': null}),
        _FakeLineSearchService([line, otherLine]),
        trackingService: trackingService,
      );
      addTearDown(repository.dispose);

      await repository.startTracking('0301');
      trackingService.queries.clear();

      await repository.startTracking('0302');

      final queriedLineIds = trackingService.queries
          .expand((lines) => lines)
          .map((queried) => queried.id)
          .toSet();
      expect(queriedLineIds, {line.id, otherLine.id});
    });

    test('atualiza as posições a cada intervalo', () {
      fakeAsync((async) {
        final trackingService = _FakeTrackingService([_position('4171')]);
        final repository = TrackingRepositoryImpl(
          _FakeRouteService({'0301': route}),
          _FakeLineSearchService([line]),
          trackingService: trackingService,
        );
        final emissions = <List<TrackedLine>>[];
        final subscription = repository.trackingRoutes.listen(emissions.add);
        async.flushMicrotasks();

        repository.startTracking('0301');
        async.flushMicrotasks();
        expect(emissions.last.single.busPositions.single.bus.code, '4171');

        trackingService.positions = [_position('5096')];
        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();

        expect(emissions.last.single.busPositions.single.bus.code, '5096');

        subscription.cancel();
        repository.dispose();
      });
    });

    test('reinicia o cronômetro ao adicionar uma linha', () {
      fakeAsync((async) {
        final trackingService = _FakeTrackingService([_position('4171')]);
        final repository = TrackingRepositoryImpl(
          _FakeRouteService({'0301': route, '0302': null}),
          _FakeLineSearchService([line, otherLine]),
          trackingService: trackingService,
        );

        repository.startTracking('0301');
        async.flushMicrotasks();
        expect(trackingService.queries, hasLength(1));

        async.elapse(const Duration(seconds: 29));
        expect(trackingService.queries, hasLength(1));

        repository.startTracking('0302');
        async.flushMicrotasks();
        // Consulta imediata com as duas linhas acompanhadas.
        final afterAdd = trackingService.queries.length;
        expect(afterAdd, 3);

        async.elapse(const Duration(seconds: 29));
        expect(trackingService.queries, hasLength(afterAdd));

        async.elapse(const Duration(seconds: 1));
        expect(trackingService.queries, hasLength(afterAdd + 2));

        repository.dispose();
      });
    });

    test('para de consultar quando não há linhas acompanhadas', () {
      fakeAsync((async) {
        final trackingService = _FakeTrackingService([_position('4171')]);
        final repository = TrackingRepositoryImpl(
          _FakeRouteService({'0301': route}),
          _FakeLineSearchService([line]),
          trackingService: trackingService,
        );

        repository.startTracking('0301');
        async.flushMicrotasks();
        final afterStart = trackingService.queries.length;

        repository.stopTracking('0301');
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 2));

        expect(trackingService.queries, hasLength(afterStart));

        repository.dispose();
      });
    });

    test('cancela o cronômetro ao descartar o repositório', () {
      fakeAsync((async) {
        final trackingService = _FakeTrackingService([_position('4171')]);
        final repository = TrackingRepositoryImpl(
          _FakeRouteService({'0301': route}),
          _FakeLineSearchService([line]),
          trackingService: trackingService,
        );

        repository.startTracking('0301');
        async.flushMicrotasks();
        final afterStart = trackingService.queries.length;

        repository.dispose();
        async.elapse(const Duration(minutes: 2));

        expect(trackingService.queries, hasLength(afterStart));
      });
    });

    test('mantém as últimas posições quando a consulta falha', () {
      fakeAsync((async) {
        final trackingService = _FakeTrackingService([_position('4171')]);
        final repository = TrackingRepositoryImpl(
          _FakeRouteService({'0301': route}),
          _FakeLineSearchService([line]),
          trackingService: trackingService,
        );
        final emissions = <List<TrackedLine>>[];
        final subscription = repository.trackingRoutes.listen(emissions.add);
        async.flushMicrotasks();

        repository.startTracking('0301');
        async.flushMicrotasks();

        trackingService.shouldThrow = true;
        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();

        // A falha não derruba o stream e preserva as últimas posições.
        expect(emissions.last.single.busPositions.single.bus.code, '4171');

        trackingService.shouldThrow = false;
        trackingService.positions = [_position('5096')];
        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();

        expect(emissions.last.single.busPositions.single.bus.code, '5096');

        subscription.cancel();
        repository.dispose();
      });
    });

    test('não consulta o serviço sem linhas acompanhadas', () {
      fakeAsync((async) {
        final trackingService = _FakeTrackingService([_position('4171')]);
        final repository = TrackingRepositoryImpl(
          _FakeRouteService({}),
          _FakeLineSearchService([]),
          trackingService: trackingService,
        );

        async.elapse(const Duration(minutes: 2));

        expect(trackingService.queries, isEmpty);

        repository.dispose();
      });
    });
  });
}

/// Deixa os eventos pendentes do stream broadcast serem entregues.
Future<void> _flushStream() => Future<void>.delayed(Duration.zero);
