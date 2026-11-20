import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meubuzu/data/services/api_client.dart';
import 'package:meubuzu/data/services/api_line_search_service.dart';
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

ApiLineSearchService buildService(MockClient client, {bool withCity = true}) {
  return ApiLineSearchService(
    ApiClient('http://127.0.0.1:8000', httpClient: client),
    FakeAuthRepository(user: _user, city: withCity ? _city : null),
  );
}

http.Response linesResponse() => http.Response(
  jsonEncode({
    'count': 2,
    'lines': [
      {
        'boardingCode': '1',
        'name': 'CENTRO - NORTE',
        'origin': 'Centro',
        'destination': 'Norte',
      },
      {
        'boardingCode': '2',
        'name': 'NORTE - CENTRO',
        'origin': 'Norte',
        'destination': 'Centro',
      },
    ],
  }),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('ApiLineSearchService', () {
    test('busca linhas na cidade selecionada com token', () async {
      late http.Request captured;
      final service = buildService(
        MockClient((request) async {
          captured = request;
          return linesResponse();
        }),
      );

      final lines = await service.search('centro');

      expect(captured.url.path, '/v1/cities/teresina/lines');
      expect(captured.url.queryParameters['q'], 'centro');
      expect(captured.headers['Authorization'], 'Bearer fake-access-token');
      expect(lines, hasLength(2));
      expect(lines.first.boardingCode, '1');
      expect(lines.first.name, 'CENTRO - NORTE');
      expect(lines.first.origin, 'Centro');
      expect(lines.first.destination, 'Norte');
    });

    test('busca por códigos usa o parâmetro codes', () async {
      late Uri url;
      final service = buildService(
        MockClient((request) async {
          url = request.url;
          return linesResponse();
        }),
      );

      await service.findByCodes(['0002', '0001']);

      expect(url.path, '/v1/cities/teresina/lines');
      expect(url.queryParameters['codes'], '0002,0001');
    });

    test('não consulta a API sem cidade selecionada', () async {
      final requests = <http.Request>[];
      final service = buildService(
        MockClient((request) async {
          requests.add(request);
          return linesResponse();
        }),
        withCity: false,
      );

      await expectLater(service.search('centro'), throwsStateError);
      expect(requests, isEmpty);
    });

    test('consulta vazia não chama a API', () async {
      final requests = <http.Request>[];
      final service = buildService(
        MockClient((request) async {
          requests.add(request);
          return linesResponse();
        }),
      );

      expect(await service.search('   '), isEmpty);
      expect(await service.findByCodes(const []), isEmpty);
      expect(requests, isEmpty);
    });
  });
}
