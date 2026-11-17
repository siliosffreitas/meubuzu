import '../../domain/models/city.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/city_repository.dart';
import '../services/api_client.dart';

/// Lista as cidades ativas usando a API do backend.
class ApiCityRepository implements CityRepository {
  ApiCityRepository(this._client, this._auth);

  final ApiClient _client;
  final AuthRepository _auth;

  @override
  Future<List<City>> fetchActiveCities() async {
    final body = await _client.get(
      '/v1/cities',
      accessToken: _auth.accessToken,
    );

    final cities = body['cities'];
    if (cities is! List) {
      return const [];
    }

    return cities
        .whereType<Map<String, dynamic>>()
        .map(City.fromJson)
        .where((city) => city.slug.isNotEmpty)
        .toList(growable: false);
  }

  @override
  void dispose() {}
}
