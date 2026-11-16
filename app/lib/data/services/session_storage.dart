import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/contracts/contracts.dart';
import '../models/stored_auth_session.dart';

/// Persistência da sessão entre execuções do aplicativo.
abstract interface class SessionStorage implements Service {
  Future<StoredAuthSession?> read();
  Future<void> write(StoredAuthSession session);
  Future<void> clear();
}

/// Usa o Keychain (iOS) e o Keystore (Android) via flutter_secure_storage.
class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'meubuzu.auth.session';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredAuthSession?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await clear();
        return null;
      }

      final session = StoredAuthSession.fromJson(decoded);
      if (session == null) {
        await clear();
      }
      return session;
    } on FormatException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(StoredAuthSession session) {
    return _storage.write(key: _key, value: jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
