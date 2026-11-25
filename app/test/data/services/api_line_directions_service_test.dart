import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meubuzu/data/services/api_client.dart';
import 'package:meubuzu/data/services/api_line_directions_service.dart';
import 'package:meubuzu/domain/models/auth_user.dart';
import 'package:meubuzu/domain/models/city.dart';

import '../../helpers/fake_auth_repository.dart';

const _user = AuthUser(id: 'user-1', email: 'ana@exemplo.com');
const _city = City(
  slug: 'sao-paulo',
  name: 'São Paulo',
  label: 'São Paulo - SP',
  state: 'SP',
  country: 'BR',
  timezone: 'America/Sao_Paulo',
  latitude: -23.55,
  longitude: -46.63,
);

ApiLineDirectionsService buildService(
  MockClient client, {
  bool withCity = true,
}) {
  return ApiLineDirectionsService(
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
  group('ApiLineDirectionsService', () {
    test('busca os sentidos na cidade selecionada com token', () async {
      late http.Request captured;
      final service = buildService(
        MockClient((request) async {
          captured = request;
          return jsonResponse({
            'boardingCode': '1012-10',
            'directions': [
              {
                'value': 1,
                'label': 'Jardim B → Terminal A',
                'hasRoute': true,
                'stopCount': 43,
              },
              {
                'value': 0,
                'label': 'Terminal A → Jardim B',
                'hasRoute': true,
                'stopCount': 42,
              },
            ],
          });
        }),
      );

      final directions = await service.findDirections('1012-10');

      expect(
        captured.url.path,
        '/v1/cities/sao-paulo/lines/1012-10/directions',
      );
      expect(captured.headers['Authorization'], 'Bearer fake-access-token');
      expect(directions.map((direction) => direction.value), [0, 1]);
      expect(directions.first.label, 'Terminal A → Jardim B');
      expect(directions.first.hasRoute, isTrue);
      expect(directions.first.stopCount, 42);
    });

    test('retorna lista vazia quando a linha não tem itinerário', () async {
      final service = buildService(
        MockClient((request) async => jsonResponse({'directions': []})),
      );

      expect(await service.findDirections('1012-10'), isEmpty);
    });

    test('não consulta a API sem cidade selecionada', () async {
      final requests = <http.Request>[];
      final service = buildService(
        MockClient((request) async {
          requests.add(request);
          return jsonResponse({'directions': []});
        }),
        withCity: false,
      );

      await expectLater(service.findDirections('1012-10'), throwsStateError);
      expect(requests, isEmpty);
    });

    test('código vazio não chama a API', () async {
      final requests = <http.Request>[];
      final service = buildService(
        MockClient((request) async {
          requests.add(request);
          return jsonResponse({'directions': []});
        }),
      );

      expect(await service.findDirections('   '), isEmpty);
      expect(requests, isEmpty);
    });
  });
}
