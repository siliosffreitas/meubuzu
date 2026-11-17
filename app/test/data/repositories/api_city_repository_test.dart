import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meubuzu/data/repositories/api_city_repository.dart';
import 'package:meubuzu/data/services/api_client.dart';
import 'package:meubuzu/domain/models/auth_user.dart';

import '../../helpers/fake_auth_repository.dart';

void main() {
  group('ApiCityRepository', () {
    ApiCityRepository buildRepository(MockClient client) {
      return ApiCityRepository(
        ApiClient('http://127.0.0.1:8000', httpClient: client),
        FakeAuthRepository(
          user: const AuthUser(id: 'user-1', email: 'ana@exemplo.com'),
        ),
      );
    }

    test('lista as cidades ativas com o token da sessão', () async {
      late http.Request captured;
      final repository = buildRepository(
        MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'cities': [
                {
                  'slug': 'teresina',
                  'name': 'Teresina',
                  'label': 'Teresina - PI',
                  'state': 'PI',
                  'country': 'BR',
                  'timezone': 'America/Fortaleza',
                  'center': {'latitude': -5.16, 'longitude': -42.79},
                  'isActive': true,
                },
              ],
            }),
            200,
          );
        }),
      );

      final cities = await repository.fetchActiveCities();

      expect(captured.method, 'GET');
      expect(captured.url.path, '/v1/cities');
      expect(captured.headers['Authorization'], 'Bearer fake-access-token');
      expect(cities, hasLength(1));
      expect(cities.single.slug, 'teresina');
      expect(cities.single.label, 'Teresina - PI');
      expect(cities.single.timezone, 'America/Fortaleza');
    });

    test('ignora itens inválidos e cidades sem slug', () async {
      final repository = buildRepository(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'cities': [
                'teresina',
                {'name': 'Sem slug'},
                {'slug': 'teresina', 'name': 'Teresina'},
              ],
            }),
            200,
          ),
        ),
      );

      final cities = await repository.fetchActiveCities();

      expect(cities, hasLength(1));
      expect(cities.single.slug, 'teresina');
    });

    test('devolve lista vazia quando a resposta não tem cidades', () async {
      final repository = buildRepository(
        MockClient((_) async => http.Response('{}', 200)),
      );

      expect(await repository.fetchActiveCities(), isEmpty);
    });

    test('propaga erro da API', () async {
      final repository = buildRepository(
        MockClient(
          (_) async => http.Response('{"code":"city_not_found"}', 404),
        ),
      );

      await expectLater(repository.fetchActiveCities(), throwsA(anything));
    });
  });
}
