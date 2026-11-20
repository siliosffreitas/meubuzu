import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meubuzu/data/services/api_client.dart';
import 'package:meubuzu/data/services/api_tracking_service.dart';
import 'package:meubuzu/domain/models/auth_user.dart';
import 'package:meubuzu/domain/models/city.dart';
import 'package:meubuzu/domain/models/line.dart';

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

const _line0301 = Line(
  name: 'Linha 35',
  origin: 'Terminal',
  destination: 'Centro',
  boardingCode: '0301',
);
const _line0245 = Line(
  name: 'Linha 47',
  origin: 'Terminal',
  destination: 'Bairro',
  boardingCode: '0245',
);

ApiTrackingService buildService(MockClient client, {City? city = _city}) {
  return ApiTrackingService(
    ApiClient('http://127.0.0.1:8000', httpClient: client),
    FakeAuthRepository(user: _user, city: city),
  );
}

http.Response jsonResponse(Object body, {int statusCode = 200}) => http.Response(
  jsonEncode(body),
  statusCode,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> position({
  required String boardingCode,
  required String vehicleCode,
  required String capturedAt,
  bool isStale = false,
}) {
  return {
    'boardingCode': boardingCode,
    'vehicleCode': vehicleCode,
    'latitude': -5.1,
    'longitude': -42.8,
    'capturedAt': capturedAt,
    'generatedAt': '2026-11-17T14:59:00Z',
    'receivedAt': '2026-11-17T15:05:01Z',
    'speed': null,
    'heading': 90.5,
    'previousLatitude': -5.11,
    'previousLongitude': -42.81,
    'isStale': isStale,
  };
}

void main() {
  group('ApiTrackingService', () {
    test('consulta todas as linhas em uma única requisição', () async {
      late http.Request captured;
      final service = buildService(
        MockClient((request) async {
          captured = request;
          return jsonResponse({
            'city': 'teresina',
            'lines': [
              {
                'boardingCode': '0301',
                'requestedCode': '0301',
                'source': 'csv_demo',
                'dataMode': 'demo',
                'isStale': true,
                'sourceStatus': 'ok',
                'positions': [
                  position(
                    boardingCode: '0301',
                    vehicleCode: '4171',
                    capturedAt: '2026-11-17T15:04:30Z',
                  ),
                ],
              },
            ],
            'unresolvedLines': [],
          });
        }),
      );

      final positions = await service.findPositions([_line0301, _line0245]);

      expect(captured.url.path, '/v1/cities/teresina/positions');
      expect(captured.url.queryParameters['codes'], '0301,0245');
      expect(captured.headers['Authorization'], 'Bearer fake-access-token');
      expect(positions, hasLength(1));
      expect(positions.single.lineCode, '0301');
      expect(positions.single.bus.code, '4171');
      expect(positions.single.capturedAt, DateTime.utc(2026, 11, 17, 15, 4, 30));
      expect(positions.single.generatedAt, DateTime.utc(2026, 11, 17, 14, 59));
      expect(positions.single.receivedAt, DateTime.utc(2026, 11, 17, 15, 5, 1));
      expect(positions.single.heading, 90.5);
      expect(positions.single.previousLatitude, -5.11);
      expect(positions.single.previousLongitude, -42.81);
      expect(positions.single.isStale, isFalse);
      expect(positions.single.dataMode, 'demo');
      expect(positions.single.source, 'csv_demo');
    });

    test('mantém nulos o heading e a posição anterior quando ausentes', () async {
      final rawPosition = position(
        boardingCode: '0301',
        vehicleCode: '4171',
        capturedAt: '2026-11-17T15:04:30Z',
      )
        ..remove('heading')
        ..remove('previousLatitude')
        ..remove('previousLongitude');

      final service = buildService(
        MockClient(
          (request) async => jsonResponse({
            'lines': [
              {
                'boardingCode': '0301',
                'positions': [rawPosition],
              },
            ],
          }),
        ),
      );

      final positions = await service.findPositions([_line0301]);

      expect(positions.single.heading, isNull);
      expect(positions.single.previousLatitude, isNull);
      expect(positions.single.previousLongitude, isNull);
    });

    test('preserva os zeros à esquerda do sgLinha e remove duplicados', () async {
      final paths = <String>[];
      final service = buildService(
        MockClient((request) async {
          paths.add(request.url.queryParameters['codes'] ?? '');
          return jsonResponse({'lines': []});
        }),
      );

      await service.findPositions([_line0301, _line0301]);

      expect(paths, ['0301']);
    });

    test('ordena posições de todas as linhas e usa metadados do bloco', () async {
      final service = buildService(
        MockClient((request) async {
          return jsonResponse({
            'lines': [
              {
                'boardingCode': '0245',
                'source': 'csv_demo',
                'dataMode': 'demo',
                'isStale': true,
                'positions': [
                  position(
                    boardingCode: '0245',
                    vehicleCode: '7788',
                    capturedAt: '2026-11-17T15:00:00Z',
                    isStale: true,
                  ),
                ],
              },
              {
                'boardingCode': '0301',
                'source': 'csv_demo',
                'dataMode': 'demo',
                'isStale': false,
                'positions': [
                  position(
                    boardingCode: '0301',
                    vehicleCode: '4171',
                    capturedAt: '2026-11-17T15:04:30Z',
                  ),
                ],
              },
            ],
          });
        }),
      );

      final positions = await service.findPositions([_line0301, _line0245]);

      expect(positions.map((item) => item.lineCode), ['0245', '0301']);
      expect(positions.last.isStale, isFalse);
      expect(positions.first.isStale, isTrue);
    });

    test('ignora posições inválidas', () async {
      final service = buildService(
        MockClient((request) async {
          return jsonResponse({
            'lines': [
              {
                'boardingCode': '0301',
                'positions': [
                  {
                    'boardingCode': '0301',
                    'vehicleCode': 'SEM_COORDENADA',
                    'latitude': null,
                    'longitude': -42.8,
                    'capturedAt': '2026-11-17T15:04:30Z',
                  },
                  position(
                    boardingCode: '0301',
                    vehicleCode: '4171',
                    capturedAt: '2026-11-17T15:04:30Z',
                  ),
                ],
              },
            ],
          });
        }),
      );

      final positions = await service.findPositions([_line0301]);

      expect(positions.map((item) => item.bus.code), ['4171']);
    });

    test('não consulta a API sem cidade selecionada', () async {
      final requests = <http.Request>[];
      final service = buildService(
        MockClient((request) async {
          requests.add(request);
          return jsonResponse({'lines': []});
        }),
        city: null,
      );

      await expectLater(service.findPositions([_line0301]), throwsStateError);
      expect(requests, isEmpty);
    });

    test('propaga erros estáveis da API', () async {
      final service = buildService(
        MockClient(
          (request) async => jsonResponse(
            {
              'code': 'subscription_required',
              'title': 'Assinatura necessária',
              'status': 402,
              'detail': 'Rastreamento exige teste ou assinatura.',
            },
            statusCode: 402,
          ),
        ),
      );

      await expectLater(
        service.findPositions([_line0301]),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 402)
              .having((error) => error.code, 'code', 'subscription_required'),
        ),
      );
    });
  });
}
