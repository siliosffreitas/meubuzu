import '../../domain/models/favorite.dart';
import '../../domain/repositories/auth_repository.dart';
import 'api_client.dart';
import 'favorites_service.dart';

/// Favoritos são globais por usuário; apenas a remoção leva cidade e
/// `boardingCode` na URL.
class ApiFavoritesService implements FavoritesService {
  ApiFavoritesService(this._client, this._auth);

  final ApiClient _client;
  final AuthRepository _auth;

  @override
  Future<List<Favorite>> fetch() async {
    final body = await _client.get(
      '/v1/favorites',
      accessToken: _auth.accessToken,
    );
    final favorites = body['favorites'];
    if (favorites is! List) {
      return const [];
    }
    return favorites
        .whereType<Map<String, dynamic>>()
        .map(Favorite.fromJson)
        .where((favorite) => favorite.displayCode.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<Favorite> add(String boardingCode, String citySlug) async {
    final body = await _client.post(
      '/v1/favorites',
      body: {'boardingCode': boardingCode, 'citySlug': citySlug},
      accessToken: _auth.accessToken,
    );
    return Favorite.fromJson(body);
  }

  @override
  Future<void> remove(String citySlug, String boardingCode) async {
    await _client.delete(
      '/v1/favorites/${Uri.encodeComponent(citySlug)}/'
      '${Uri.encodeComponent(boardingCode)}',
      accessToken: _auth.accessToken,
    );
  }
}
