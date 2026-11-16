import 'package:flutter/foundation.dart';

import '../../domain/models/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/stored_auth_session.dart';
import '../services/api_client.dart';
import '../services/session_storage.dart';

/// Implementação real da autenticação, usando a API do backend.
///
/// Os tokens nunca saem deste repositório: a interface expõe apenas o usuário
/// atual e o estado da sessão.
class ApiAuthRepository extends ChangeNotifier implements AuthRepository {
  ApiAuthRepository(this._client, this._storage);

  final ApiClient _client;
  final SessionStorage _storage;

  StoredAuthSession? _session;
  int _generation = 0;

  @override
  AuthUser? get currentUser => _session?.user;

  @override
  bool get isAuthenticated => _session != null;

  @override
  Future<void> requestEmailCode(String email) async {
    await _mapApiErrors(
      () => _client.post(
        '/v1/auth/request-code',
        body: {'email': _normalize(email)},
      ),
    );
  }

  @override
  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    final body = await _mapApiErrors(
      () => _client.post(
        '/v1/auth/verify-code',
        body: {'email': _normalize(email), 'code': code},
      ),
      mapInvalidCode: true,
    );

    await _storeAndApply(_sessionFromAuthResponse(body));
  }

  @override
  Future<void> restoreSession() async {
    try {
      final stored = await _storage.read();
      if (stored == null) {
        return;
      }

      _session = stored;
      _generation++;
      notifyListeners();
    } catch (error) {
      // Uma falha no Keychain/Keystore não pode impedir o app de abrir.
      if (kDebugMode) {
        debugPrint('Falha ao restaurar a sessão: $error');
      }
    }
  }

  @override
  Future<void> validateSession() async {
    final initial = _session;
    if (initial == null) {
      return;
    }

    final generation = _generation;

    try {
      final profile = await _client.get(
        '/v1/me',
        accessToken: initial.accessToken,
      );
      if (_isStale(generation)) {
        return;
      }
      await _applyProfile(profile, initial);
      return;
    } on NetworkException {
      // Sem conexão: mantém a sessão e tenta novamente na próxima chamada.
      return;
    } on ApiException catch (error) {
      if (error.statusCode != 401) {
        return;
      }
    }

    StoredAuthSession refreshed;
    try {
      refreshed = await _rotate(initial);
    } on NetworkException {
      return;
    } on ApiException catch (error) {
      if (_isStale(generation)) {
        return;
      }
      if (error.statusCode == 401) {
        await _clearSession();
      }
      return;
    }

    if (_isStale(generation)) {
      return;
    }

    try {
      final profile = await _client.get(
        '/v1/me',
        accessToken: refreshed.accessToken,
      );
      if (_isStale(generation)) {
        return;
      }
      await _applyProfile(profile, refreshed);
    } on NetworkException {
      if (_isStale(generation)) {
        return;
      }
      await _storeAndApply(refreshed);
    } on ApiException catch (error) {
      if (_isStale(generation)) {
        return;
      }
      if (error.statusCode == 401) {
        await _clearSession();
      } else {
        await _storeAndApply(refreshed);
      }
    }
  }

  @override
  Future<void> logout() async {
    final session = _session;
    await _clearSession();

    if (session == null) {
      return;
    }

    try {
      await _client.post('/v1/auth/logout', accessToken: session.accessToken);
    } catch (_) {
      // Logout local já aconteceu; a revogação no servidor é melhor esforço.
    }
  }

  Future<Map<String, dynamic>> _mapApiErrors(
    Future<Map<String, dynamic>> Function() action, {
    bool mapInvalidCode = false,
  }) async {
    try {
      return await action();
    } on ApiException catch (error) {
      if (error.statusCode == 429) {
        throw RateLimitedException(
          code: error.code,
          retryAfter: error.retryAfter,
        );
      }
      if (mapInvalidCode && error.statusCode == 401) {
        throw InvalidCodeException(error.code);
      }
      rethrow;
    }
  }

  Future<StoredAuthSession> _rotate(StoredAuthSession current) async {
    final body = await _client.post(
      '/v1/auth/refresh',
      body: {'refreshToken': current.refreshToken},
    );
    return _sessionFromAuthResponse(body, fallbackUser: current.user);
  }

  StoredAuthSession _sessionFromAuthResponse(
    Map<String, dynamic> json, {
    AuthUser? fallbackUser,
  }) {
    final accessToken = json['accessToken'];
    final refreshToken = json['refreshToken'];

    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty) {
      throw const FormatException('Resposta de autenticação inválida.');
    }

    final userJson = json['user'];
    final entitlements = json['entitlements'];
    final accessLevel = entitlements is Map<String, dynamic>
        ? entitlements['accessLevel'] as String?
        : null;

    return StoredAuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: AuthUser(
        id: userJson is Map<String, dynamic>
            ? userJson['id'] as String? ?? ''
            : fallbackUser?.id ?? '',
        email: userJson is Map<String, dynamic>
            ? userJson['email'] as String? ?? ''
            : fallbackUser?.email ?? '',
        accessLevel: accessLevel ?? fallbackUser?.accessLevel ?? 'catalog_only',
      ),
    );
  }

  Future<void> _applyProfile(
    Map<String, dynamic> profile,
    StoredAuthSession session,
  ) async {
    final entitlements = profile['entitlements'];
    final accessLevel = entitlements is Map<String, dynamic>
        ? entitlements['accessLevel'] as String?
        : null;

    final user = session.user.copyWith(
      id: profile['id'] as String?,
      email: profile['email'] as String?,
      accessLevel: accessLevel,
    );

    await _storeAndApply(session.copyWith(user: user));
  }

  Future<void> _storeAndApply(StoredAuthSession session) async {
    _session = session;
    _generation++;
    notifyListeners();
    await _persist(session);
  }

  Future<void> _clearSession() async {
    _session = null;
    _generation++;
    notifyListeners();
    try {
      await _storage.clear();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Falha ao limpar a sessão: $error');
      }
    }
  }

  Future<void> _persist(StoredAuthSession session) async {
    try {
      await _storage.write(session);
    } catch (error) {
      // A sessão continua válida em memória; apenas não sobrevive ao restart.
      if (kDebugMode) {
        debugPrint('Falha ao salvar a sessão: $error');
      }
    }
  }

  bool _isStale(int generation) => generation != _generation;

  String _normalize(String email) => email.trim().toLowerCase();
}
