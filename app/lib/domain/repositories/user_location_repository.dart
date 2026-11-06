import '../models/bus_stop.dart';
import '../models/user_coordinates.dart';
import '../contracts/contracts.dart';

/// Motivos pelos quais a localização do usuário não pôde ser obtida.
enum UserLocationFailure {
  noGpsHardware,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

/// Erro publicado em [UserLocationRepository.location].
class UserLocationException implements Exception {
  const UserLocationException(this.failure);

  final UserLocationFailure failure;

  @override
  String toString() => 'UserLocationException($failure)';
}

/// Contrato de acesso à localização do usuário.
abstract interface class UserLocationRepository implements Repository {
  /// Localização atual do usuário e suas atualizações.
  ///
  /// A última posição obtida é reemitida para novos ouvintes. Quando a
  /// localização não pode ser obtida, o stream publica um
  /// [UserLocationException].
  Stream<UserCoordinates> get location;

  /// Paradas de ônibus próximas da última localização obtida.
  ///
  /// Considera as paradas a até 500 metros do usuário. A última lista obtida é
  /// reemitida para novos ouvintes. Quando o catálogo de paradas não pode ser
  /// consultado, o stream publica o erro correspondente.
  Stream<List<BusStop>> get nearbyStops;

  /// Busca a localização atual no dispositivo.
  ///
  /// Executa a sequência hardware de GPS → serviço ligado → permissão →
  /// posição. Use [requestPermission] como `false` para apenas revalidar o
  /// estado, sem abrir o diálogo de permissão novamente.
  Future<void> refresh({bool requestPermission = true});

  /// Abre as configurações de localização do sistema.
  Future<void> openLocationSettings();

  /// Abre as configurações do próprio app.
  Future<void> openAppSettings();

  /// Libera os recursos do repositório.
  @override
  void dispose();
}
