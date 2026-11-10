import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/domain/models/bus.dart';
import 'package:meubuzu/domain/models/bus_position.dart';
import 'package:meubuzu/domain/models/bus_stop.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/domain/models/route.dart';
import 'package:meubuzu/domain/models/tracked_line.dart';
import 'package:meubuzu/domain/models/user_coordinates.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_tracking_camera.dart';

const _line = Line(
  id: '46',
  name: 'MOCAMBINHO DUQUE DE CAXIAS',
  origin: 'MOCAMBINHO',
  destination: 'MOCAMBINHO',
  boardingCode: '0301',
  latitude: -5.10,
  longitude: -42.80,
);

const _otherLine = Line(
  id: '47',
  name: 'OUTRA LINHA',
  origin: 'CENTRO',
  destination: 'SHOPPING',
  boardingCode: '0302',
  latitude: -5.20,
  longitude: -42.90,
);

const _lineWithoutCoordinates = Line(
  id: '48',
  name: 'LINHA SEM COORDENADAS',
  origin: 'CENTRO',
  destination: 'SHOPPING',
  boardingCode: '0303',
);

const _routeStart = UserCoordinates(latitude: -5.11, longitude: -42.81);
const _routeEnd = UserCoordinates(latitude: -5.12, longitude: -42.82);
const _otherRoute = UserCoordinates(latitude: -5.21, longitude: -42.91);

BusPosition _busPosition(
  String busCode, {
  double latitude = -5.13,
  double longitude = -42.83,
}) {
  return BusPosition(
    bus: Bus(code: busCode),
    latitude: latitude,
    longitude: longitude,
    capturedAt: DateTime.utc(2023, 6, 4, 11, 58),
  );
}

BusStop _stop(String id, {double latitude = -5.14, double longitude = -42.84}) {
  return BusStop(
    id: id,
    code: '10$id',
    name: 'PARADA $id',
    address: 'Rua $id',
    latitude: latitude,
    longitude: longitude,
  );
}

TrackedLine _tracked(
  Line line, {
  Route? route,
  List<BusPosition> busPositions = const [],
}) {
  return TrackedLine(line: line, route: route, busPositions: busPositions);
}

List<(double, double)> _coordinatesOf(List<UserCoordinates> positions) {
  return [
    for (final position in positions) (position.latitude, position.longitude),
  ];
}

void main() {
  group('trackedLinesCoordinates', () {
    test('monta as coordenadas de todas as rotas restantes', () {
      final coordinates = trackedLinesCoordinates([
        _tracked(_line, route: Route(positions: [_routeStart, _routeEnd])),
        _tracked(_otherLine, route: Route(positions: [_otherRoute])),
      ]);

      expect(_coordinatesOf(coordinates), const [
        (-5.11, -42.81),
        (-5.12, -42.82),
        (-5.21, -42.91),
      ]);
    });

    test('usa as posições dos ônibus quando a linha não tem rota', () {
      final coordinates = trackedLinesCoordinates([
        _tracked(
          _line,
          busPositions: [_busPosition('4171'), _busPosition('5096')],
        ),
      ]);

      expect(_coordinatesOf(coordinates), const [
        (-5.13, -42.83),
        (-5.13, -42.83),
      ]);
    });

    test('usa a coordenada da linha quando não há rota nem ônibus', () {
      final coordinates = trackedLinesCoordinates([_tracked(_line)]);

      expect(_coordinatesOf(coordinates), const [(-5.10, -42.80)]);
    });

    test('prioriza a rota quando há rota e ônibus', () {
      final coordinates = trackedLinesCoordinates([
        _tracked(
          _line,
          route: Route(positions: [_routeStart]),
          busPositions: [_busPosition('4171')],
        ),
      ]);

      expect(_coordinatesOf(coordinates), const [(-5.11, -42.81)]);
    });

    test('ignora linhas sem nenhuma coordenada', () {
      final coordinates = trackedLinesCoordinates([
        _tracked(_lineWithoutCoordinates),
        _tracked(_otherLine, route: Route(positions: [_otherRoute])),
      ]);

      expect(_coordinatesOf(coordinates), const [(-5.21, -42.91)]);
    });

    test('retorna vazio sem linhas restantes', () {
      expect(trackedLinesCoordinates(const []), isEmpty);
    });
  });

  group('userAndNearbyStopsCoordinates', () {
    const position = UserCoordinates(latitude: -5.15, longitude: -42.85);

    test('monta a posição do usuário e as paradas próximas', () {
      final coordinates = userAndNearbyStopsCoordinates(
        position: position,
        nearbyStops: [_stop('1'), _stop('2')],
      );

      expect(_coordinatesOf(coordinates), const [
        (-5.15, -42.85),
        (-5.14, -42.84),
        (-5.14, -42.84),
      ]);
    });

    test('retorna apenas o usuário quando não há paradas', () {
      final coordinates = userAndNearbyStopsCoordinates(
        position: position,
        nearbyStops: const [],
      );

      expect(_coordinatesOf(coordinates), const [(-5.15, -42.85)]);
    });

    test('retorna vazio quando a localização não está disponível', () {
      final coordinates = userAndNearbyStopsCoordinates(
        position: null,
        nearbyStops: [_stop('1')],
      );

      expect(coordinates, isEmpty);
    });
  });
}
