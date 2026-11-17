import '../../domain/models/line.dart';
import '../../domain/repositories/auth_repository.dart';
import '../config/api_paths.dart';
import 'api_client.dart';
import 'line_search_service.dart';

/// Consulta as linhas do catálogo remoto da cidade selecionada.
///
/// Substitui o `AssetLineSearchService`: o backend mantém as linhas vinculadas
/// ao catálogo da cidade e resolve busca por código, nome e código de embarque.
class ApiLineSearchService implements LineSearchService {
  ApiLineSearchService(this._client, this._auth);

  final ApiClient _client;
  final AuthRepository _auth;

  @override
  Future<List<Line>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    return _fetchLines({'q': trimmed});
  }

  @override
  Future<List<Line>> findByCodes(Iterable<String> codes) async {
    final normalized = codes
        .map((code) => code.trim())
        .where((code) => code.isNotEmpty)
        .toList();
    if (normalized.isEmpty) {
      return const [];
    }
    return _fetchLines({'codes': normalized.join(',')});
  }

  Future<List<Line>> _fetchLines(Map<String, String> queryParameters) async {
    final city = _auth.selectedCity;
    if (city == null || city.slug.isEmpty) {
      throw StateError(
        'É necessário escolher uma cidade para consultar linhas.',
      );
    }

    final uri = Uri.parse(ApiPaths.city(city.slug, 'lines'))
        .replace(queryParameters: queryParameters);
    final body = await _client.get(
      uri.toString(),
      accessToken: _auth.accessToken,
    );

    final lines = body['lines'];
    if (lines is! List) {
      return const [];
    }

    return lines
        .whereType<Map<String, dynamic>>()
        .map(Line.fromJson)
        .where((line) => line.id.isNotEmpty)
        .toList(growable: false);
  }
}
