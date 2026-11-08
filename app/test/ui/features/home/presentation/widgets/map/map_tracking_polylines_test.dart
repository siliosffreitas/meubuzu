import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/domain/models/route.dart';
import 'package:meubuzu/domain/models/tracked_line.dart';
import 'package:meubuzu/domain/models/user_coordinates.dart';
import 'package:meubuzu/ui/core/extensions/line_map_color.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_tracking_polylines.dart';

const _line = Line(
  id: '46',
  name: 'MOCAMBINHO DUQUE DE CAXIAS',
  origin: 'MOCAMBINHO',
  destination: 'MOCAMBINHO',
  boardingCode: '0301',
);
final _trackedLine = TrackedLine(
  line: _line,
  route: Route(
    positions: const [
      UserCoordinates(latitude: -5.1, longitude: -42.8),
      UserCoordinates(latitude: -5.2, longitude: -42.9),
    ],
  ),
  busPositions: const [],
);

void main() {
  group('buildTrackingPolylines', () {
    test('não cria polylines sem linhas acompanhadas', () {
      expect(buildTrackingPolylines(const []), isEmpty);
    });

    test('ignora linhas sem traçado', () {
      final tracked = TrackedLine(
        line: _line,
        route: null,
        busPositions: const [],
      );

      expect(buildTrackingPolylines([tracked]), isEmpty);
    });

    test('cria a polyline com os pontos do traçado', () {
      final polylines = buildTrackingPolylines([_trackedLine]);

      expect(polylines, hasLength(1));
      final polyline = polylines.single;
      expect(polyline.polylineId.value, 'tracked-0301');
      expect(polyline.points, const [LatLng(-5.1, -42.8), LatLng(-5.2, -42.9)]);
    });

    test('usa a mesma cor de identificação da linha', () {
      final polylines = buildTrackingPolylines([_trackedLine]);

      expect(polylines.single.color, _line.mapColor);
    });

    test('usa o id da linha quando não há código de embarque', () {
      const line = Line(
        id: '46',
        name: 'MOCAMBINHO DUQUE DE CAXIAS',
        origin: 'MOCAMBINHO',
        destination: 'MOCAMBINHO',
        boardingCode: '0101',
      );
      final tracked = TrackedLine(
        line: line,
        route: Route(
          positions: const [UserCoordinates(latitude: -5.1, longitude: -42.8)],
        ),
        busPositions: const [],
      );

      final polylines = buildTrackingPolylines([tracked]);

      expect(polylines.single.polylineId.value, 'tracked-46');
      expect(trackedLineKey(tracked), '46');
    });
  });
}
