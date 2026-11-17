import 'dart:math' as math;

import '../../domain/models/bus_stop.dart';
import '../../domain/models/user_coordinates.dart';
import '../../domain/repositories/auth_repository.dart';
import '../config/api_paths.dart';
import 'api_client.dart';
import 'bus_stop_service.dart';

/// Consulta as paradas do catálogo remoto da cidade selecionada.
///
/// Substitui o `AssetBusStopService` (CSV local) no app: o backend mantém as
/// paradas vinculadas à cidade e serve as consultas quentes do cache Redis.
class ApiBusStopService implements BusStopService {
  ApiBusStopService(this._client, this._auth);

  final ApiClient _client;
  final AuthRepository _auth;

  @override
  Future<List<BusStop>> findWithinBounds(
    UserCoordinates southwest,
    UserCoordinates northeast,
  ) async {
    final south = math.min(southwest.latitude, northeast.latitude);
    final north = math.max(southwest.latitude, northeast.latitude);
    final west = math.min(southwest.longitude, northeast.longitude);
    final east = math.max(southwest.longitude, northeast.longitude);

    return _fetchStops({'bbox': '$west,$south,$east,$north'});
  }

  @override
  Future<List<BusStop>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    return _fetchStops({'q': trimmed});
  }

  @override
  Future<List<BusStop>> findByCodes(Iterable<String> codes) async {
    final normalized = codes
        .map((code) => code.trim())
        .where((code) => code.isNotEmpty)
        .toList();
    if (normalized.isEmpty) {
      return const [];
    }
    return _fetchStops({'codes': normalized.join(',')});
  }

  Future<List<BusStop>> _fetchStops(Map<String, String> queryParameters) async {
    final city = _auth.selectedCity;
    if (city == null || city.slug.isEmpty) {
      throw StateError(
        'É necessário escolher uma cidade para consultar paradas.',
      );
    }

    final uri = Uri.parse(ApiPaths.city(city.slug, 'stops'))
        .replace(queryParameters: queryParameters);
    final body = await _client.get(
      uri.toString(),
      accessToken: _auth.accessToken,
    );

    final stops = body['stops'];
    if (stops is! List) {
      return const [];
    }

    return stops
        .whereType<Map<String, dynamic>>()
        .map(BusStop.fromJson)
        .where((stop) => stop.code.isNotEmpty)
        .toList(growable: false);
  }
}
