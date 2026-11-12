import '../../../../../../domain/models/bus_stop.dart';
import '../../../../../../domain/models/tracked_line.dart';
import '../../../../../../domain/models/user_coordinates.dart';

/// Coordenadas que representam as linhas ainda acompanhadas no mapa.
///
/// Prioriza o traçado completo de cada linha; se a rota ainda não estiver
/// disponível, usa as posições atuais dos ônibus e, por último, a coordenada de
/// referência da linha.
List<UserCoordinates> trackedLinesCoordinates(
  Iterable<TrackedLine> trackedLines,
) {
  final coordinates = <UserCoordinates>[];

  for (final tracked in trackedLines) {
    final routePositions = tracked.route?.positions;
    if (routePositions != null && routePositions.isNotEmpty) {
      coordinates.addAll(routePositions);
      continue;
    }

    if (tracked.busPositions.isNotEmpty) {
      coordinates.addAll([
        for (final position in tracked.busPositions)
          UserCoordinates(
            latitude: position.latitude,
            longitude: position.longitude,
          ),
      ]);
      continue;
    }

    final latitude = tracked.line.latitude;
    final longitude = tracked.line.longitude;
    if (latitude != null && longitude != null) {
      coordinates.add(
        UserCoordinates(latitude: latitude, longitude: longitude),
      );
    }
  }

  return coordinates;
}

/// Coordenadas do usuário e das paradas da área visível exibidas no mapa.
///
/// Retorna uma lista vazia quando a localização do usuário não está disponível.
List<UserCoordinates> userAndVisibleStopsCoordinates({
  required UserCoordinates? position,
  required Iterable<BusStop> visibleStops,
}) {
  if (position == null) {
    return const [];
  }

  return [
    position,
    for (final stop in visibleStops)
      UserCoordinates(latitude: stop.latitude, longitude: stop.longitude),
  ];
}
