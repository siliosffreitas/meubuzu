import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/domain/models/bus.dart';
import 'package:meubuzu/domain/models/bus_position.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/domain/models/tracked_line.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_tracking_directions.dart';

const _line = Line(
  id: '46',
  name: 'MOCAMBINHO DUQUE DE CAXIAS',
  origin: 'MOCAMBINHO',
  destination: 'MOCAMBINHO',
  boardingCode: '0301',
);

const _otherLine = Line(
  id: '47',
  name: 'OUTRA LINHA',
  origin: 'CENTRO',
  destination: 'SHOPPING',
  boardingCode: '0302',
);

BusPosition _position(
  double latitude,
  double longitude, {
  String busCode = '4171',
}) {
  return BusPosition(
    bus: Bus(code: busCode),
    latitude: latitude,
    longitude: longitude,
    capturedAt: DateTime.utc(2023, 6, 4, 12),
  );
}

TrackedLine _tracked(List<BusPosition> positions, {Line line = _line}) {
  return TrackedLine(line: line, route: null, busPositions: positions);
}

void main() {
  group('bearingBetween', () {
    test('aponta para o norte', () {
      expect(
        bearingBetween(_position(0, 0), _position(0.01, 0)),
        closeTo(0, 0.5),
      );
    });

    test('aponta para o leste', () {
      expect(
        bearingBetween(_position(0, 0), _position(0, 0.01)),
        closeTo(90, 0.5),
      );
    });

    test('aponta para o sul', () {
      expect(
        bearingBetween(_position(0, 0), _position(-0.01, 0)),
        closeTo(180, 0.5),
      );
    });

    test('aponta para o oeste', () {
      expect(
        bearingBetween(_position(0, 0), _position(0, -0.01)),
        closeTo(270, 0.5),
      );
    });

    test('aponta para o nordeste', () {
      expect(
        bearingBetween(_position(0, 0), _position(0.01, 0.01)),
        closeTo(45, 1),
      );
    });
  });

  group('TrackingBusDirections', () {
    test('não cria direção na primeira captura', () {
      final directions = TrackingBusDirections();

      directions.update([
        _tracked([_position(-5.10, -42.80)]),
      ]);

      expect(directions.bearings, isEmpty);
    });

    test('calcula a direção a partir da captura anterior', () {
      final directions = TrackingBusDirections();
      final current = _tracked([_position(-5.09, -42.80)]);

      directions.update([
        _tracked([_position(-5.10, -42.80)]),
      ]);
      directions.update([current]);

      final position = current.busPositions.single;
      expect(
        directions.bearings[trackedBusKey(current, position)],
        closeTo(0, 1),
      );
    });

    test('mantém a direção quando o ônibus não se desloca', () {
      final directions = TrackingBusDirections();
      final current = _tracked([_position(-5.09, -42.80)]);

      directions.update([
        _tracked([_position(-5.10, -42.80)]),
      ]);
      directions.update([current]);
      final bearing = directions
          .bearings[trackedBusKey(current, current.busPositions.single)];
      expect(bearing, isNotNull);

      directions.update([current]);

      expect(
        directions.bearings[trackedBusKey(
          current,
          current.busPositions.single,
        )],
        bearing,
      );
    });

    test('atualiza a direção a cada novo deslocamento', () {
      final directions = TrackingBusDirections();
      final current = _tracked([_position(-5.09, -42.81)]);

      directions.update([
        _tracked([_position(-5.09, -42.80)]),
      ]);
      directions.update([current]);

      expect(
        directions.bearings[trackedBusKey(
          current,
          current.busPositions.single,
        )],
        closeTo(270, 1),
      );
    });

    test('mantém as direções de ônibus e linhas independentes', () {
      final directions = TrackingBusDirections();
      final first = _tracked([_position(-5.09, -42.80, busCode: '4171')]);
      final second = _tracked([
        _position(-5.09, -42.80, busCode: '5096'),
      ], line: _otherLine);

      directions.update([
        _tracked([_position(-5.10, -42.80, busCode: '4171')]),
        _tracked([_position(-5.10, -42.81, busCode: '5096')], line: _otherLine),
      ]);
      directions.update([first, second]);

      expect(
        directions.bearings[trackedBusKey(first, first.busPositions.single)],
        closeTo(0, 1),
      );
      expect(
        directions.bearings[trackedBusKey(second, second.busPositions.single)],
        closeTo(45, 1),
      );
      expect(directions.bearings, hasLength(2));
    });

    test('descarta a direção quando o ônibus sai do rastreamento', () {
      final directions = TrackingBusDirections();

      directions.update([
        _tracked([_position(-5.10, -42.80)]),
      ]);
      directions.update([
        _tracked([_position(-5.09, -42.80)]),
      ]);
      expect(directions.bearings, isNotEmpty);

      directions.update(const []);

      expect(directions.bearings, isEmpty);
    });

    test('não expõe o mapa interno de direções', () {
      final directions = TrackingBusDirections();

      expect(
        () => directions.bearings['0301:4171'] = 90,
        throwsUnsupportedError,
      );
    });
  });
}
