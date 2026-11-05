import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/data/models/bus_stop.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/nearby_stop_markers.dart';

const _busStop = BusStop(
  id: '1',
  code: '2362',
  name: 'T-SANTA FÉ',
  address: 'Rua B, Teresina - PI',
  latitude: -5.165446,
  longitude: -42.791169,
);

void main() {
  group('buildNearbyStopMarkers', () {
    test('cria um marcador com posição e informações da parada', () {
      final markers = buildNearbyStopMarkers(const [_busStop]);

      expect(markers, hasLength(1));
      final marker = markers.single;
      expect(marker.markerId.value, 'stop-1');
      expect(marker.position.latitude, _busStop.latitude);
      expect(marker.position.longitude, _busStop.longitude);
      expect(marker.infoWindow.title, _busStop.name);
      expect(marker.infoWindow.snippet, _busStop.address);
    });

    test('não cria marcadores quando não há paradas', () {
      expect(buildNearbyStopMarkers(const []), isEmpty);
    });
  });
}
