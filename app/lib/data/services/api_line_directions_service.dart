import '../../domain/models/line_direction.dart';
import '../../domain/repositories/auth_repository.dart';
import '../config/api_paths.dart';
import 'api_client.dart';
import 'line_directions_service.dart';

/// Consulta os sentidos disponíveis no catálogo remoto da cidade selecionada.
///
/// Usa `GET /v1/cities/{citySlug}/lines/{boardingCode}/directions`. A lista é
/// vazia quando a linha ainda não possui itinerário cadastrado.
class ApiLineDirectionsService implements LineDirectionsService {
  ApiLineDirectionsService(this._client, this._auth);

  final ApiClient _client;
  final AuthRepository _auth;

  @override
  Future<List<LineDirection>> findDirections(String lineCode) async {
    final normalized = lineCode.trim();
    if (normalized.isEmpty) {
      return const [];
    }

    final city = _auth.selectedCity;
    if (city == null || city.slug.isEmpty) {
      throw StateError(
        'É necessário escolher uma cidade para consultar os sentidos.',
      );
    }

    final uri = ApiPaths.city(city.slug, 'lines/$normalized/directions');
    final body = await _client.get(uri, accessToken: _auth.accessToken);

    final directions = body['directions'];
    if (directions is! List) {
      return const [];
    }

    final parsed = <LineDirection>[];
    for (final item in directions) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      parsed.add(LineDirection.fromJson(item));
    }
    parsed.sort((a, b) => a.value.compareTo(b.value));
    return List<LineDirection>.unmodifiable(parsed);
  }
}
