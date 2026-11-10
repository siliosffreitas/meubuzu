import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../../domain/models/bus_stop.dart';

/// Prévia somente leitura do mapa, com o marcador da parada.
class BusStopMapPreview extends StatelessWidget {
  const BusStopMapPreview({super.key, required this.busStop});

  static const double height = 190;

  final BusStop busStop;

  @override
  Widget build(BuildContext context) {
    final target = LatLng(busStop.latitude, busStop.longitude);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: target, zoom: 16),
          markers: {
            Marker(
              markerId: MarkerId('bus-stop-${busStop.id}'),
              position: target,
              infoWindow: InfoWindow(
                title: busStop.name,
                snippet: busStop.address,
              ),
            ),
          },
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          myLocationButtonEnabled: false,
          myLocationEnabled: false,
          scrollGesturesEnabled: false,
          zoomGesturesEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
        ),
      ),
    );
  }
}
