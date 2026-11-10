import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../../domain/models/bus_stop.dart';
import '../../../home/presentation/widgets/map/nearby_stop_markers.dart';

/// Prévia somente leitura do mapa, com o marcador da parada.
///
/// O marcador usa o mesmo ícone (anel + nome) e a mesma lógica dos marcadores
/// de paradas próximas exibidos no mapa principal.
class BusStopMapPreview extends StatefulWidget {
  const BusStopMapPreview({super.key, required this.busStop});

  static const double height = 190;

  final BusStop busStop;

  @override
  State<BusStopMapPreview> createState() => _BusStopMapPreviewState();
}

class _BusStopMapPreviewState extends State<BusStopMapPreview> {
  final NearbyStopMarkerIcons _stopIcons = NearbyStopMarkerIcons();

  @override
  void initState() {
    super.initState();
    _ensureIcon();
  }

  @override
  void didUpdateWidget(BusStopMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busStop.name != widget.busStop.name) {
      _ensureIcon();
    }
  }

  Future<void> _ensureIcon() async {
    await _stopIcons.ensure([widget.busStop.name]);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final busStop = widget.busStop;
    final target = LatLng(busStop.latitude, busStop.longitude);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: BusStopMapPreview.height,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: target, zoom: 16),
          markers: buildNearbyStopMarkers(
            [busStop],
            iconFor: (stop) => _stopIcons.iconFor(stop.name),
            anchorFor: (stop) => _stopIcons.anchorFor(stop.name),
          ),
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
