import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meubuzu/data/services/api_client.dart';
import 'package:meubuzu/data/services/api_favorites_service.dart';
import 'package:meubuzu/domain/models/auth_user.dart';

import '../../helpers/fake_auth_repository.dart';

const _user = AuthUser(id: 'user-1', email: 'ana@exemplo.com');

ApiFavoritesService buildService(MockClient client) => ApiFavoritesService(
  ApiClient('http://127.0.0.1:8000', httpClient: client),
  FakeAuthRepository(user: _user),
);

http.Response jsonResponse(Object body, {int statusCode = 200}) =>
    http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> cityJson(String slug, String name) => {
  'slug': slug,
  'name': name,
  'label': '$name - PI',
  'timezone': 'America/Fortaleza',
};

Map<String, dynamic> lineJson(String code, String name) => {
  'boardingCode': code,
  'line': {
    'boardingCode': code,
    'name': name,
    'origin': 'Origem',
    'destination': 'Destino',
  },
  'createdAt': '2026-11-18T11:15:08Z',
};

void main() {
  group('ApiFavoritesService', () {
    test('achata os grupos mantendo ordem e cidade de cada linha', () async {
      late http.Request captured;
      final service = buildService(
        MockClient((request) async {
          captured = request;
          return jsonResponse({
            'cities': [
              {
                'city': cityJson('teresina', 'Teresina'),
                'lines': [lineJson('2', 'LINHA 2'), lineJson('10', 'LINHA 10')],
              },
              {
                'city': cityJson('outra', 'Outra'),
                'lines': [lineJson('9', 'LINHA 9')],
              },
            ],
          });
        }),
      );

      final favorites = await service.fetch();

      expect(captured.url.path, '/v1/favorites');
      expect(captured.headers['Authorization'], 'Bearer fake-access-token');
      expect(favorites.map((item) => item.displayCode), ['2', '10', '9']);
      expect(favorites.map((item) => item.citySlug), [
        'teresina',
        'teresina',
        'outra',
      ]);
      expect(favorites.map((item) => item.city.displayLabel), [
        'Teresina - PI',
        'Teresina - PI',
        'Outra - PI',
      ]);
    });

    test('retorna lista vazia quando não há grupos', () async {
      final service = buildService(
        MockClient((_) async => jsonResponse({'cities': []})),
      );

      expect(await service.fetch(), isEmpty);
    });

    test('add continua usando a resposta plana do POST', () async {
      late http.Request captured;
      final service = buildService(
        MockClient((request) async {
          captured = request;
          return jsonResponse({
            ...lineJson('0301', 'LINHA 0301'),
            'city': cityJson('teresina', 'Teresina'),
          }, statusCode: 201);
        }),
      );

      final favorite = await service.add('0301', 'teresina');

      expect(captured.method, 'POST');
      expect(captured.url.path, '/v1/favorites');
      expect(jsonDecode(captured.body), {
        'boardingCode': '0301',
        'citySlug': 'teresina',
      });
      expect(favorite.displayCode, '0301');
      expect(favorite.citySlug, 'teresina');
    });
  });
}
