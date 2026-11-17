import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meubuzu/data/services/api_client.dart';
import 'package:meubuzu/data/services/api_route_service.dart';
import 'package:meubuzu/domain/models/auth_user.dart';
import 'package:meubuzu/domain/models/city.dart';

import '../../helpers/fake_auth_repository.dart';

const _user = AuthUser(id: 'user-1', email: 'ana@exemplo.com');
const _city = City(
  slug: 'teresina',
  name: 'Teresina',
  label: 'Teresina - PI',
  state: 'PI',
  country: 'BR',
  timezone: 'America/Fortaleza',
  latitude: -5.16,
  longitude: -42.79,
);

ApiRouteService buildService(MockClient client, {bool withCity = true}) {
  return ApiRouteService(
    ApiClient('http://127.0.0.1:8000', httpClient: client),
    FakeAuthRepository(user: _user, city: withCity ? _city : null),
  );
}

http.Response jsonResponse(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('ApiRouteService', () {
    test('busca o traçado da linha na cidade selecionada com token', () async {
      late http.Request captured;
      final service = buildService(
        MockClient((request) async {
          captured = request;
          return jsonResponse({
            'lineId': '11111111-1111-1111-1111-111111111111',
            'direction': 0,
            'coordinates': [
              [-5.16, -42.79],
              [-5.17, -42.80],
            ],
          });
        }),
      );

      final route = await service.findRoute('0001');

      expect(captured.url.path, '/v1/cities/teresina/lines/0001/route');
      expect(captured.headers['Authorization'], 'Bearer fake-access-token');
      expect(route, isNotNull);
      expect(route!.positions, hasLength(2));
      expect(route.positions.first.latitude, -5.16);
      expect(route.positions.first.longitude, -42.79);
      expect(route.positions.last.latitude, -5.17);
      expect(route.positions.last.longitude, -42.80);
    });

    test('retorna null quando a API informa route: null', () async {
      final service = buildService(
        MockClient((request) async => jsonResponse({'route': null})),
      );

      expect(await service.findRoute('0001'), isNull);
    });

    test('retorna null quando não há coordenadas válidas', () async {
      final service = buildService(
        MockClient((request) async => jsonResponse({'coordinates': []})),
      );

      expect(await service.findRoute('0001'), isNull);
    });

    test('não consulta a API sem cidade selecionada', () async {
      final requests = <http.Request>[];
      final service = buildService(
        MockClient((request) async {
          requests.add(request);
          return jsonResponse({'coordinates': []});
        }),
        withCity: false,
      );

      await expectLater(service.findRoute('0001'), throwsStateError);
      expect(requests, isEmpty);
    });

    test('código vazio não chama a API', () async {
      final requests = <http.Request>[];
      final service = buildService(
        MockClient((request) async {
          requests.add(request);
          return jsonResponse({'coordinates': []});
        }),
      );

      expect(await service.findRoute('   '), isNull);
      expect(requests, isEmpty);
    });
  });
}
