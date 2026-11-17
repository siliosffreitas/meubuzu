import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meubuzu/data/models/stored_auth_session.dart';
import 'package:meubuzu/data/repositories/auth_repository.dart';
import 'package:meubuzu/data/services/api_client.dart';
import 'package:meubuzu/data/services/session_storage.dart';
import 'package:meubuzu/domain/models/auth_user.dart';
import 'package:meubuzu/domain/models/city.dart';
import 'package:meubuzu/domain/repositories/auth_repository.dart';

/// Armazenamento em memória para os testes, sem plugins de plataforma.
class InMemorySessionStorage implements SessionStorage {
  StoredAuthSession? session;
  int writes = 0;
  int clears = 0;

  @override
  Future<StoredAuthSession?> read() async => session;

  @override
  Future<void> write(StoredAuthSession value) async {
    writes++;
    session = value;
  }

  @override
  Future<void> clear() async {
    clears++;
    session = null;
  }
}

StoredAuthSession _storedSession({String access = 'access-1'}) {
  return StoredAuthSession(
    accessToken: access,
    refreshToken: 'refresh-1',
    user: const AuthUser(id: 'user-1', email: 'ana@exemplo.com'),
  );
}

String _sessionBody({
  String access = 'access-1',
  String refresh = 'refresh-1',
  Map<String, dynamic>? selectedCity,
}) {
  return jsonEncode({
    'accessToken': access,
    'refreshToken': refresh,
    'user': {'id': 'user-1', 'email': 'ana@exemplo.com'},
    'preferences': {'selectedCity': selectedCity, 'version': 0},
    'entitlements': {'accessLevel': 'catalog_only'},
  });
}

const _teresinaJson = {
  'slug': 'teresina',
  'name': 'Teresina',
  'label': 'Teresina - PI',
  'state': 'PI',
  'country': 'BR',
  'timezone': 'America/Fortaleza',
  'center': {'latitude': -5.16, 'longitude': -42.79},
  'isActive': true,
  'coverageNote': null,
};

const _teresina = City(
  slug: 'teresina',
  name: 'Teresina',
  label: 'Teresina - PI',
  state: 'PI',
  country: 'BR',
  timezone: 'America/Fortaleza',
  latitude: -5.16,
  longitude: -42.79,
);

void main() {
  group('ApiAuthRepository', () {
    late InMemorySessionStorage storage;

    setUp(() {
      storage = InMemorySessionStorage();
    });

    ApiAuthRepository buildRepository(MockClient client) {
      return ApiAuthRepository(
        ApiClient('http://127.0.0.1:8000', httpClient: client),
        storage,
      );
    }

    test('envia o e-mail normalizado para request-code', () async {
      late http.Request captured;
      final repository = buildRepository(
        MockClient((request) async {
          captured = request;
          return http.Response('{"message":"ok"}', 202);
        }),
      );

      await repository.requestEmailCode('  Ana@Exemplo.com ');

      expect(captured.method, 'POST');
      expect(captured.url.path, '/v1/auth/request-code');
      expect(jsonDecode(captured.body), {'email': 'ana@exemplo.com'});
    });

    test('confirma o código, persiste a sessão e notifica', () async {
      final repository = buildRepository(
        MockClient((request) async {
          expect(request.url.path, '/v1/auth/verify-code');
          expect(jsonDecode(request.body), {
            'email': 'ana@exemplo.com',
            'code': '123456',
          });
          return http.Response(_sessionBody(), 200);
        }),
      );
      var notifications = 0;
      repository.addListener(() => notifications++);

      await repository.verifyEmailCode(
        email: 'ana@exemplo.com',
        code: '123456',
      );

      expect(repository.isAuthenticated, isTrue);
      expect(repository.currentUser?.email, 'ana@exemplo.com');
      expect(repository.currentUser?.accessLevel, 'catalog_only');
      expect(storage.session?.accessToken, 'access-1');
      expect(notifications, greaterThan(0));
    });

    test('traduz 401 do verify-code para InvalidCodeException', () async {
      final repository = buildRepository(
        MockClient(
          (request) async =>
              http.Response('{"code":"code_expired","detail":"expirado"}', 401),
        ),
      );

      await expectLater(
        repository.verifyEmailCode(email: 'ana@exemplo.com', code: '000000'),
        throwsA(
          isA<InvalidCodeException>().having(
            (error) => error.code,
            'code',
            'code_expired',
          ),
        ),
      );
      expect(repository.isAuthenticated, isFalse);
    });

    test('traduz 429 para RateLimitedException com retryAfter', () async {
      final repository = buildRepository(
        MockClient(
          (request) async => http.Response(
            '{"code":"rate_limited","detail":"aguarde","retryAfter":30}',
            429,
          ),
        ),
      );

      await expectLater(
        repository.requestEmailCode('ana@exemplo.com'),
        throwsA(
          isA<RateLimitedException>()
              .having((error) => error.code, 'code', 'rate_limited')
              .having(
                (error) => error.retryAfter,
                'retryAfter',
                const Duration(seconds: 30),
              ),
        ),
      );
    });

    test('restaura a sessão salva no armazenamento', () async {
      storage.session = _storedSession();
      final repository = buildRepository(
        MockClient((_) async => http.Response('', 500)),
      );

      await repository.restoreSession();

      expect(repository.isAuthenticated, isTrue);
      expect(repository.currentUser?.email, 'ana@exemplo.com');
    });

    test('valida a sessão com /v1/me', () async {
      storage.session = _storedSession();
      final repository = buildRepository(
        MockClient((request) async {
          expect(request.url.path, '/v1/me');
          expect(request.headers['Authorization'], 'Bearer access-1');
          return http.Response(
            jsonEncode({
              'id': 'user-1',
              'email': 'ana@exemplo.com',
              'entitlements': {'accessLevel': 'trial'},
            }),
            200,
          );
        }),
      );
      await repository.restoreSession();

      await repository.validateSession();

      expect(repository.currentUser?.accessLevel, 'trial');
    });

    test('renova a sessão quando /v1/me responde 401', () async {
      storage.session = _storedSession();
      var meCalls = 0;
      final repository = buildRepository(
        MockClient((request) async {
          if (request.url.path == '/v1/me') {
            meCalls++;
            if (meCalls == 1) {
              return http.Response('{"code":"token_expired"}', 401);
            }
            expect(request.headers['Authorization'], 'Bearer access-2');
            return http.Response(
              jsonEncode({
                'id': 'user-1',
                'email': 'ana@exemplo.com',
                'entitlements': {'accessLevel': 'catalog_only'},
              }),
              200,
            );
          }
          if (request.url.path == '/v1/auth/refresh') {
            expect(jsonDecode(request.body), {'refreshToken': 'refresh-1'});
            return http.Response(
              _sessionBody(access: 'access-2', refresh: 'refresh-2'),
              200,
            );
          }
          return http.Response('', 404);
        }),
      );
      await repository.restoreSession();

      await repository.validateSession();

      expect(repository.isAuthenticated, isTrue);
      expect(storage.session?.accessToken, 'access-2');
      expect(storage.session?.refreshToken, 'refresh-2');
    });

    test('limpa a sessão quando o refresh falha com 401', () async {
      storage.session = _storedSession();
      final repository = buildRepository(
        MockClient((request) async {
          if (request.url.path == '/v1/me') {
            return http.Response('{"code":"token_expired"}', 401);
          }
          return http.Response('{"code":"refresh_reused"}', 401);
        }),
      );
      await repository.restoreSession();

      await repository.validateSession();

      expect(repository.isAuthenticated, isFalse);
      expect(storage.session, isNull);
      expect(storage.clears, greaterThan(0));
    });

    test('mantém a sessão quando a validação falha por rede', () async {
      storage.session = _storedSession();
      final repository = buildRepository(
        MockClient((_) async => throw http.ClientException('sem rede')),
      );
      await repository.restoreSession();

      await repository.validateSession();

      expect(repository.isAuthenticated, isTrue);
    });

    test('logout limpa a sessão mesmo sem rede para revogar', () async {
      storage.session = _storedSession();
      final repository = buildRepository(
        MockClient((_) async => throw http.ClientException('sem rede')),
      );
      await repository.restoreSession();

      await repository.logout();

      expect(repository.isAuthenticated, isFalse);
      expect(storage.session, isNull);
    });

    test('verify-code restaura a cidade salva no backend', () async {
      final repository = buildRepository(
        MockClient(
          (_) async =>
              http.Response(_sessionBody(selectedCity: _teresinaJson), 200),
        ),
      );

      await repository.verifyEmailCode(
        email: 'ana@exemplo.com',
        code: '123456',
      );

      expect(repository.selectedCity?.slug, 'teresina');
      expect(repository.selectedCity?.timezone, 'America/Fortaleza');
      expect(repository.hasSelectedCity, isTrue);
      expect(storage.session?.selectedCity?.slug, 'teresina');
    });

    test('selectCity envia a cidade e persiste a resposta', () async {
      storage.session = _storedSession();
      late http.Request captured;
      final repository = buildRepository(
        MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'selectedCity': _teresinaJson,
              'version': 1,
              'updatedAt': '2026-11-16T12:00:00Z',
            }),
            200,
          );
        }),
      );
      await repository.restoreSession();

      await repository.selectCity(_teresina);

      expect(captured.method, 'PUT');
      expect(captured.url.path, '/v1/me/preferences');
      expect(captured.headers['Authorization'], 'Bearer access-1');
      expect(jsonDecode(captured.body), {'selectedCitySlug': 'teresina'});
      expect(repository.selectedCity?.slug, 'teresina');
      expect(storage.session?.selectedCity?.slug, 'teresina');
    });

    test('selectCity mantém a escolha local quando a rede falha', () async {
      storage.session = _storedSession();
      final repository = buildRepository(
        MockClient((_) async => throw http.ClientException('sem rede')),
      );
      await repository.restoreSession();

      await repository.selectCity(_teresina);

      expect(repository.selectedCity?.slug, 'teresina');
      expect(storage.session?.selectedCity?.slug, 'teresina');
    });

    test('reenvia a cidade pendente na próxima validação', () async {
      storage.session = _storedSession();
      var offline = true;
      var putCalls = 0;
      final repository = buildRepository(
        MockClient((request) async {
          if (request.url.path == '/v1/me') {
            return http.Response(
              jsonEncode({
                'id': 'user-1',
                'email': 'ana@exemplo.com',
                'preferences': {'selectedCity': null, 'version': 0},
                'entitlements': {'accessLevel': 'catalog_only'},
              }),
              200,
            );
          }
          if (request.url.path == '/v1/me/preferences') {
            putCalls++;
            if (offline) {
              throw http.ClientException('sem rede');
            }
            return http.Response(
              jsonEncode({'selectedCity': _teresinaJson, 'version': 1}),
              200,
            );
          }
          return http.Response('', 404);
        }),
      );
      await repository.restoreSession();

      await repository.selectCity(_teresina);
      expect(repository.selectedCity?.slug, 'teresina');

      offline = false;
      await repository.validateSession();

      expect(putCalls, 2);
      expect(repository.selectedCity?.slug, 'teresina');
      expect(storage.session?.selectedCity?.slug, 'teresina');
    });

    test('selectCity reverte quando a cidade está inativa', () async {
      storage.session = _storedSession();
      final repository = buildRepository(
        MockClient((_) async => http.Response('{"code":"city_inactive"}', 409)),
      );
      await repository.restoreSession();

      await expectLater(
        repository.selectCity(_teresina),
        throwsA(
          isA<CityUnavailableException>().having(
            (error) => error.code,
            'code',
            'city_inactive',
          ),
        ),
      );

      expect(repository.selectedCity, isNull);
      expect(storage.session?.selectedCity, isNull);
    });

    test('validateSession limpa a cidade removida no backend', () async {
      storage.session = _storedSession().copyWith(selectedCity: _teresina);
      final repository = buildRepository(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'id': 'user-1',
              'email': 'ana@exemplo.com',
              'preferences': {'selectedCity': null, 'version': 1},
              'entitlements': {'accessLevel': 'catalog_only'},
            }),
            200,
          ),
        ),
      );
      await repository.restoreSession();
      expect(repository.hasSelectedCity, isTrue);

      await repository.validateSession();

      expect(repository.selectedCity, isNull);
      expect(storage.session?.selectedCity, isNull);
    });
  });
}
