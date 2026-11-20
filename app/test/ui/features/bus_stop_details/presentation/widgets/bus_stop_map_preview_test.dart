import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:meubuzu/domain/models/bus_stop.dart';
import 'package:meubuzu/ui/features/bus_stop_details/presentation/widgets/bus_stop_map_preview.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/nearby_stop_markers.dart';

const _busStop = BusStop(
  code: '174',
  name: 'PRAÇA DO IPÊ',
  address: 'Rua do Mercado, 180 · em frente à praça',
  latitude: -5.1,
  longitude: -42.8,
);

void main() {
  testWidgets('BusStopMapPreview mostra o marcador na posição da parada', (
    tester,
  ) async {
    final icons = NearbyStopMarkerIcons();
    await tester.runAsync(() => icons.ensure([_busStop.name]));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BusStopMapPreview(busStop: _busStop, markerIcons: icons),
        ),
      ),
    );

    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.markers, hasLength(1));

    final marker = map.markers.single;
    expect(marker.markerId.value, 'stop-${_busStop.code}');
    expect(marker.position, LatLng(_busStop.latitude, _busStop.longitude));
    expect(marker.infoWindow.title, _busStop.name);
    expect(marker.infoWindow.snippet, _busStop.address);
    expect(
      map.initialCameraPosition.target,
      LatLng(_busStop.latitude, _busStop.longitude),
    );
  });
}
