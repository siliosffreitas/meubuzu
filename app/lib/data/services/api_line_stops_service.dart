import '../../domain/repositories/auth_repository.dart';
import '../config/api_paths.dart';
import 'api_client.dart';
import 'line_stops_service.dart';

/// Consulta o relacionamento linha/parada no catálogo remoto da cidade.
///
/// Substitui o `AssetLineStopsService` (asset `lines_paradas.json`): o backend
/// mantém as paradas de cada linha na ordem do itinerário.
class ApiLineStopsService implements LineStopsService {
  ApiLineStopsService(this._client, this._auth);

  final ApiClient _client;
  final AuthRepository _auth;

  @override
  Future<List<String>> findStopCodesForLine(String lineCode) async {
    final normalized = lineCode.trim();
    if (normalized.isEmpty) {
      return const [];
    }
    return _fetchCodes(ApiPaths.city(
      _citySlug(),
      'lines/$normalized/stops',
    ), key: 'code');
  }

  @override
  Future<List<String>> findLineCodesForStop(String stopCode) async {
    final normalized = stopCode.trim();
    if (normalized.isEmpty) {
      return const [];
    }
    return _fetchCodes(ApiPaths.city(
      _citySlug(),
      'stops/$normalized/lines',
    ), key: 'boardingCode');
  }

  String _citySlug() {
    final city = _auth.selectedCity;
    if (city == null || city.slug.isEmpty) {
      throw StateError(
        'É necessário escolher uma cidade para consultar o catálogo.',
      );
    }
    return city.slug;
  }

  Future<List<String>> _fetchCodes(String path, {required String key}) async {
    final body = await _client.get(
      path,
      accessToken: _auth.accessToken,
    );

    final items = body['stops'] ?? body['lines'];
    if (items is! List) {
      return const [];
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map((item) => item[key]?.toString().trim() ?? '')
        .where((code) => code.isNotEmpty)
        .toList(growable: false);
  }
}
