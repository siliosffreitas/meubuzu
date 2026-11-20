import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meubuzu/data/services/api_client.dart';
import 'package:meubuzu/data/services/api_line_stops_service.dart';
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

ApiLineStopsService buildService(MockClient client, {bool withCity = true}) {
  return ApiLineStopsService(
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
  group('ApiLineStopsService', () {
    test('busca as paradas de uma linha na ordem do itinerário', () async {
      late http.Request captured;
      final service = buildService(
        MockClient((request) async {
          captured = request;
          return jsonResponse({
            'count': 2,
            'stops': [
              {
                'code': '100',
                'name': 'PRIMEIRA',
              },
              {
                'code': '200',
                'name': 'SEGUNDA',
              },
            ],
          });
        }),
      );

      final codes = await service.findStopCodesForLine('0001');

      expect(captured.url.path, '/v1/cities/teresina/lines/0001/stops');
      expect(captured.headers['Authorization'], 'Bearer fake-access-token');
      expect(codes, ['100', '200']);
    });

    test('busca as linhas que passam por uma parada pelo código', () async {
      late http.Request captured;
      final service = buildService(
        MockClient((request) async {
          captured = request;
          return jsonResponse({
            'count': 2,
            'lines': [
              {
                'boardingCode': '0001',
                'name': 'CENTRO - NORTE',
              },
              {
                'boardingCode': '0002',
                'name': 'NORTE - CENTRO',
              },
            ],
          });
        }),
      );

      final codes = await service.findLineCodesForStop('100');

      expect(captured.url.path, '/v1/cities/teresina/stops/100/lines');
      expect(captured.headers['Authorization'], 'Bearer fake-access-token');
      expect(codes, ['0001', '0002']);
    });

    test('ignora itens sem código', () async {
      final service = buildService(
        MockClient((request) async {
          return jsonResponse({
            'stops': [
              {'code': ''},
              {'name': 'SEM CÓDIGO'},
              {'code': '200'},
            ],
          });
        }),
      );

      expect(await service.findStopCodesForLine('0001'), ['200']);
    });

    test('não consulta a API sem cidade selecionada', () async {
      final requests = <http.Request>[];
      final service = buildService(
        MockClient((request) async {
          requests.add(request);
          return jsonResponse({'stops': []});
        }),
        withCity: false,
      );

      await expectLater(
        service.findStopCodesForLine('0001'),
        throwsStateError,
      );
      await expectLater(
        service.findLineCodesForStop('100'),
        throwsStateError,
      );
      expect(requests, isEmpty);
    });

    test('códigos vazios não chamam a API', () async {
      final requests = <http.Request>[];
      final service = buildService(
        MockClient((request) async {
          requests.add(request);
          return jsonResponse({'stops': []});
        }),
      );

      expect(await service.findStopCodesForLine('   '), isEmpty);
      expect(await service.findLineCodesForStop('   '), isEmpty);
      expect(requests, isEmpty);
    });
  });
}
