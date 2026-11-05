import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../../../data/models/bus_stop.dart';

/// Cria os marcadores das paradas próximas exibidas no mapa.
Set<Marker> buildNearbyStopMarkers(Iterable<BusStop> stops) {
  return {
    for (final stop in stops)
      Marker(
        markerId: MarkerId('stop-${stop.id}'),
        position: LatLng(stop.latitude, stop.longitude),
        infoWindow: InfoWindow(title: stop.name, snippet: stop.address),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
  };
}
