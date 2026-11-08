import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../../../domain/models/tracked_line.dart';
import '../../../../../core/extensions/line_map_color.dart';

/// Cria as polylines dos traçados acompanhados.
///
/// A cor de cada traçado é a mesma identificação visual usada para a linha na
/// busca e nos detalhes ([LineMapColor.mapColor]).
Set<Polyline> buildTrackingPolylines(List<TrackedLine> trackedLines) {
  final polylines = <Polyline>{};

  for (final tracked in trackedLines) {
    final positions = tracked.route?.positions;
    if (positions == null || positions.isEmpty) {
      continue;
    }

    polylines.add(
      Polyline(
        polylineId: PolylineId('tracked-${trackedLineKey(tracked)}'),
        points: positions
            .map((position) => LatLng(position.latitude, position.longitude))
            .toList(growable: false),
        color: tracked.line.mapColor,
        width: 5,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    );
  }

  return polylines;
}

/// Identificador estável da linha acompanhada.
String trackedLineKey(TrackedLine tracked) => tracked.line.boardingCode ?? '${tracked.line.id}-${tracked.line.name}';
