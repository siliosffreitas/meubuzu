import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/data/repositories/tracking_repository.dart';
import 'package:meubuzu/data/services/line_search_service.dart';
import 'package:meubuzu/data/services/route_service.dart';
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

void main() {
  const line = Line(
    id: '46',
    name: 'MOCAMBINHO DUQUE DE CAXIAS',
    origin: 'MOCAMBINHO',
    destination: 'MOCAMBINHO',
    boardingCode: '0301',
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
  });
}

/// Deixa os eventos pendentes do stream broadcast serem entregues.
Future<void> _flushStream() => Future<void>.delayed(Duration.zero);
