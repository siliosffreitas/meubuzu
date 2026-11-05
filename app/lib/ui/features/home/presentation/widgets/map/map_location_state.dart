import '../../../../../../data/models/bus_stop.dart';
import '../../../../../../data/models/user_coordinates.dart';

/// Estado da localização do usuário exibido no mapa.
///
/// Cada estado concreto representa uma situação distinta da tela e indica à
/// view qual conteúdo exibir para o usuário.
abstract class MapLocationState {
  const MapLocationState();

  /// Coordenadas da localização atual (se houver).
  UserCoordinates? get position => null;

  /// Paradas próximas que devem ser exibidas no mapa.
  List<BusStop> get nearbyStops => const [];

  /// Indica se a localização está disponível.
  bool get isReady => position != null;
}

/// Nenhuma verificação de localização foi iniciada ainda.
class MapLocationIdle extends MapLocationState {
  const MapLocationIdle();
}

/// A localização está sendo verificada (GPS, serviço, permissão e posição).
class MapLocationChecking extends MapLocationState {
  const MapLocationChecking();
}

/// A localização do usuário está disponível.
class MapLocationReady extends MapLocationState {
  const MapLocationReady(this.position);

  @override
  final UserCoordinates position;
}

/// A localização do usuário está disponível e as paradas próximas foram
/// carregadas.
class MapLocationNearbyStopsReady extends MapLocationReady {
  const MapLocationNearbyStopsReady({
    required UserCoordinates position,
    required this.nearbyStops,
  }) : super(position);

  @override
  final List<BusStop> nearbyStops;
}

/// O dispositivo não possui hardware de GPS.
class MapLocationNoGpsHardware extends MapLocationState {
  const MapLocationNoGpsHardware();
}

/// O serviço de localização (GPS) está desligado.
class MapLocationServiceDisabled extends MapLocationState {
  const MapLocationServiceDisabled();
}

/// A permissão de localização foi negada.
class MapLocationPermissionDenied extends MapLocationState {
  const MapLocationPermissionDenied();
}

/// A permissão de localização foi negada permanentemente.
class MapLocationPermissionDeniedForever extends MapLocationState {
  const MapLocationPermissionDeniedForever();
}

/// Não foi possível obter a localização por outro motivo.
class MapLocationUnavailable extends MapLocationState {
  const MapLocationUnavailable();
}
