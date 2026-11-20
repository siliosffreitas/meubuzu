import '../../domain/models/favorite.dart';
import '../../domain/repositories/auth_repository.dart';
import 'api_client.dart';
import 'favorites_service.dart';

/// Favoritos são globais por usuário; apenas a remoção leva cidade e
/// `boardingCode` na URL. A listagem vem agrupada por cidade e é achatada aqui
/// para manter o contrato interno do repositório.
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
    final groups = body['cities'];
    if (groups is! List) {
      return const [];
    }
    final favorites = <Favorite>[];
    for (final group in groups) {
      if (group is! Map<String, dynamic>) {
        continue;
      }
      final city = group['city'];
      final lines = group['lines'];
      if (city is! Map<String, dynamic> || lines is! List) {
        continue;
      }
      for (final line in lines) {
        if (line is! Map<String, dynamic>) {
          continue;
        }
        // A cidade vem uma vez por grupo no contrato do endpoint.
        favorites.add(Favorite.fromJson({...line, 'city': city}));
      }
    }
    return favorites
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
