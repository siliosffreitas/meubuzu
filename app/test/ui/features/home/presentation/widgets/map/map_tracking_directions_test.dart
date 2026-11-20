import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/domain/models/bus.dart';
import 'package:meubuzu/domain/models/bus_position.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/domain/models/tracked_line.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_tracking_directions.dart';

const _line = Line(
  name: 'MOCAMBINHO DUQUE DE CAXIAS',
  origin: 'MOCAMBINHO',
  destination: 'MOCAMBINHO',
  boardingCode: '0301',
);

const _otherLine = Line(
  name: 'OUTRA LINHA',
  origin: 'CENTRO',
  destination: 'SHOPPING',
  boardingCode: '0302',
);

BusPosition _position({
  String busCode = '4171',
  double heading = 90,
  bool withHeading = true,
}) {
  return BusPosition(
    bus: Bus(code: busCode),
    latitude: -5.10,
    longitude: -42.80,
    previousLatitude: -5.11,
    previousLongitude: -42.81,
    heading: withHeading ? heading : null,
    capturedAt: DateTime.utc(2023, 6, 4, 12),
  );
}

TrackedLine _tracked(List<BusPosition> positions, {Line line = _line}) {
  return TrackedLine(line: line, route: null, busPositions: positions);
}

void main() {
  group('trackedBusKey', () {
    test('identifica o ônibus dentro da linha acompanhada', () {
      final position = _position();
      final tracked = _tracked([position]);

      expect(trackedBusKey(tracked, position), '0301:4171');
    });
  });

  group('TrackingBusDirections', () {
    test('usa o heading do backend já na primeira atualização', () {
      final directions = TrackingBusDirections();
      final tracked = _tracked([_position(heading: 135)]);

      directions.update([tracked]);

      final position = tracked.busPositions.single;
      expect(
        directions.bearings[trackedBusKey(tracked, position)],
        135,
      );
    });

    test('não cria direção quando o backend não envia heading', () {
      final directions = TrackingBusDirections();

      directions.update([_tracked([_position(withHeading: false)])]);

      expect(directions.bearings, isEmpty);
    });

    test('não depende de atualizações anteriores', () {
      final tracked = _tracked([_position(heading: 45)]);
      final first = TrackingBusDirections()..update([tracked]);
      final second = TrackingBusDirections()..update([tracked]);

      expect(first.bearings, second.bearings);
    });

    test('reconstrói as direções a cada atualização', () {
      final directions = TrackingBusDirections();
      final tracked = _tracked([_position(heading: 45)]);

      directions.update([tracked]);
      expect(directions.bearings.values, [45]);

      directions.update([_tracked([_position(heading: 270)])]);
      expect(directions.bearings.values, [270]);

      directions.update([_tracked([_position(withHeading: false)])]);
      expect(directions.bearings, isEmpty);
    });

    test('mantém direções de ônibus e linhas independentes', () {
      final directions = TrackingBusDirections();
      final first = _tracked([_position(busCode: '4171', heading: 0)]);
      final second = _tracked(
        [_position(busCode: '5096', heading: 180)],
        line: _otherLine,
      );

      directions.update([first, second]);

      expect(directions.bearings[trackedBusKey(first, first.busPositions.single)], 0);
      expect(
        directions.bearings[trackedBusKey(second, second.busPositions.single)],
        180,
      );
      expect(directions.bearings, hasLength(2));
    });

    test('descarta a direção quando o ônibus sai do rastreamento', () {
      final directions = TrackingBusDirections();

      directions.update([_tracked([_position()])]);
      expect(directions.bearings, isNotEmpty);

      directions.update(const []);

      expect(directions.bearings, isEmpty);
    });

    test('normaliza heading fora do intervalo de uma volta', () {
      final directions = TrackingBusDirections();

      directions.update([_tracked([_position(heading: 405)])]);

      expect(directions.bearings.values, [45]);
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
