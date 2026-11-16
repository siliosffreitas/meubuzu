import 'dart:io';

import 'package:flutter/foundation.dart';

/// Endereço do backend usado pelo aplicativo.
///
/// Em desenvolvimento, o padrão depende da plataforma: o emulador Android
/// enxerga a máquina host em `10.0.2.2`, enquanto o simulador iOS usa
/// `127.0.0.1`. Para sobrescrever (celular físico ou staging):
///
/// ```sh
/// flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8000
/// ```
abstract final class ApiConfig {
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// URL base sem barra final.
  static String get baseUrl {
    final configured = _configuredBaseUrl.trim();
    if (configured.isNotEmpty) {
      return _withoutTrailingSlash(configured);
    }

    if (!kDebugMode) {
      throw StateError(
        'API_BASE_URL não configurada. Em builds de release, informe a URL '
        'com --dart-define=API_BASE_URL=https://api.exemplo.com.',
      );
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static String _withoutTrailingSlash(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }
}
