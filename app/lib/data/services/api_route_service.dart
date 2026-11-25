import '../../domain/models/route.dart';
import '../../domain/models/user_coordinates.dart';
import '../../domain/repositories/auth_repository.dart';
import '../config/api_paths.dart';
import 'api_client.dart';
import 'route_service.dart';

/// Consulta o traçado da linha no catálogo remoto da cidade selecionada.
///
/// Substitui o `AssetRouteService`: o backend expõe o traçado em
/// `GET /v1/cities/{citySlug}/lines/{boardingCode}/route`, identificado apenas
/// pelo `sgLinha`.
class ApiRouteService implements RouteService {
  ApiRouteService(this._client, this._auth);

  final ApiClient _client;
  final AuthRepository _auth;

  @override
  Future<Route?> findRoute(String lineCode, {int? direction}) async {
    final normalized = lineCode.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final city = _auth.selectedCity;
    if (city == null || city.slug.isEmpty) {
      throw StateError(
        'É necessário escolher uma cidade para consultar o traçado.',
      );
    }

    final path = ApiPaths.city(city.slug, 'lines/$normalized/route');
    final uri = direction == null
        ? path
        : Uri.parse(path)
            .replace(queryParameters: {'direction': '$direction'})
            .toString();
    final body = await _client.get(
      uri,
      accessToken: _auth.accessToken,
    );

    final coordinates = body['coordinates'];
    if (coordinates is! List || coordinates.isEmpty) {
      return null;
    }

    final positions = <UserCoordinates>[];
    for (final coordinate in coordinates) {
      if (coordinate is! List || coordinate.length < 2) {
        continue;
      }
      final latitude = (coordinate[0] as num?)?.toDouble();
      final longitude = (coordinate[1] as num?)?.toDouble();
      if (latitude == null || longitude == null) {
        continue;
      }
      positions.add(UserCoordinates(latitude: latitude, longitude: longitude));
    }

    if (positions.isEmpty) {
      return null;
    }
    return Route(positions: List<UserCoordinates>.unmodifiable(positions));
  }
}
