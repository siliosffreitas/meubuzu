import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meubuzu/data/services/api_bus_stop_service.dart';
import 'package:meubuzu/data/services/api_client.dart';
import 'package:meubuzu/domain/models/auth_user.dart';
import 'package:meubuzu/domain/models/city.dart';
import 'package:meubuzu/domain/models/user_coordinates.dart';

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

ApiBusStopService buildService(MockClient client, {bool withCity = true}) {
  return ApiBusStopService(
    ApiClient('http://127.0.0.1:8000', httpClient: client),
    FakeAuthRepository(user: _user, city: withCity ? _city : null),
  );
}

http.Response stopsResponse() => http.Response(
  jsonEncode({
    'count': 2,
    'stops': [
      {
        'id': '11111111-1111-1111-1111-111111111111',
        'code': '2362',
        'name': 'T-SANTA FÉ',
        'address': 'Rua B, Teresina - PI',
        'latitude': -5.165446,
        'longitude': -42.791169,
      },
      {
        'id': '22222222-2222-2222-2222-222222222222',
        'code': '1848',
        'name': 'BENTINHO',
        'address': 'Rua Seis, Teresina - PI',
        'latitude': -5.164533,
        'longitude': -42.789342,
      },
    ],
  }),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('ApiBusStopService', () {
    test('busca paradas na área visível da cidade selecionada', () async {
      late http.Request captured;
      final service = buildService(
        MockClient((request) async {
          captured = request;
          return stopsResponse();
        }),
      );

      final stops = await service.findWithinBounds(
        const UserCoordinates(latitude: -5.166, longitude: -42.792),
        const UserCoordinates(latitude: -5.164, longitude: -42.789),
      );

      expect(
        captured.url.path,
        '/v1/cities/teresina/stops',
      );
      expect(
        captured.url.queryParameters['bbox'],
        '-42.792,-5.166,-42.789,-5.164',
      );
      expect(captured.headers['Authorization'], 'Bearer fake-access-token');
      expect(stops, hasLength(2));
      expect(stops.first.code, '2362');
      expect(stops.first.name, 'T-SANTA FÉ');
      expect(stops.first.latitude, -5.165446);
      expect(stops.last.code, '1848');
    });

    test('normaliza os cantos informados em ordem inversa', () async {
      late Uri url;
      final service = buildService(
        MockClient((request) async {
          url = request.url;
          return stopsResponse();
        }),
      );

      await service.findWithinBounds(
        const UserCoordinates(latitude: -5.164, longitude: -42.789),
        const UserCoordinates(latitude: -5.166, longitude: -42.792),
      );

      expect(url.queryParameters['bbox'], '-42.792,-5.166,-42.789,-5.164');
    });

    test('busca por texto e ignora consulta vazia', () async {
      final requests = <Uri>[];
      final service = buildService(
        MockClient((request) async {
          requests.add(request.url);
          return stopsResponse();
        }),
      );

      expect(await service.search('   '), isEmpty);
      expect(requests, isEmpty);

      await service.search(' santa fe ');
      expect(requests, hasLength(1));
      expect(requests.single.queryParameters['q'], 'santa fe');
    });

    test('busca por códigos e preserva a ordem devolvida pela API', () async {
      late Uri url;
      final service = buildService(
        MockClient((request) async {
          url = request.url;
          return stopsResponse();
        }),
      );

      final stops = await service.findByCodes([' 1848 ', '', '2362']);

      expect(url.queryParameters['codes'], '1848,2362');
      expect(stops.map((stop) => stop.code), ['2362', '1848']);
    });

    test('falha sem cidade selecionada sem fazer requisição', () async {
      var calls = 0;
      final service = buildService(
        MockClient((request) async {
          calls++;
          return stopsResponse();
        }),
        withCity: false,
      );

      await expectLater(
        service.findWithinBounds(
          const UserCoordinates(latitude: -5.16, longitude: -42.79),
          const UserCoordinates(latitude: -5.15, longitude: -42.78),
        ),
        throwsA(isA<StateError>()),
      );
      expect(calls, 0);
    });

    test('devolve lista vazia quando a API não traz paradas', () async {
      final service = buildService(
        MockClient((request) async {
          return http.Response(
            jsonEncode({'count': 0}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      expect(await service.findByCodes(['9999']), isEmpty);
    });
  });
}
