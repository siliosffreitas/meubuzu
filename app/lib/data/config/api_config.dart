import 'dart:io';

import 'package:flutter/foundation.dart';

/// Endereço do backend usado pelo aplicativo.
///
/// Os valores vêm do `app/.env`, passado no build com:
///
/// ```sh
/// flutter run --dart-define-from-file=.env
/// flutter build apk --debug --dart-define-from-file=.env
/// ```
///
/// Variáveis aceitas:
///
/// - `API_BASE_URL`: URL usada em todas as plataformas. Tem precedência e é o
///   lugar indicado para o IP da máquina em um celular físico ou para
///   staging/produção.
/// - `API_BASE_URL_ANDROID` / `API_BASE_URL_IOS`: usadas quando `API_BASE_URL`
///   está vazia (útil para manter o emulador Android e o simulador iOS no
///   mesmo arquivo).
///
/// Sem nenhuma variável, builds de debug mantêm os padrões locais: o emulador
/// Android enxerga a máquina host em `10.0.2.2`, enquanto o simulador iOS usa
/// `127.0.0.1`. Builds de release exigem uma URL configurada.
abstract final class ApiConfig {
  static const _genericBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _androidBaseUrl = String.fromEnvironment('API_BASE_URL_ANDROID');
  static const _iosBaseUrl = String.fromEnvironment('API_BASE_URL_IOS');

  /// URL base sem barra final.
  static String get baseUrl {
    final configured = configuredBaseUrl(
      isAndroid: Platform.isAndroid,
      generic: _genericBaseUrl,
      android: _androidBaseUrl,
      ios: _iosBaseUrl,
    );

    if (configured != null) {
      return _withoutTrailingSlash(configured);
    }

    if (!kDebugMode) {
      throw StateError(
        'API_BASE_URL não configurada. Em builds de release, informe a URL '
        'no app/.env e use --dart-define-from-file=.env.',
      );
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  /// Resolve a URL configurada, com precedência de `API_BASE_URL`.
  ///
  /// Exposta para testes: em produção os valores vêm de `String.fromEnvironment`
  /// preenchido pelo `--dart-define-from-file`.
  @visibleForTesting
  static String? configuredBaseUrl({
    required bool isAndroid,
    required String generic,
    required String android,
    required String ios,
  }) {
    final platformBaseUrl = isAndroid ? android : ios;
    return _firstNonEmpty([generic, platformBaseUrl]);
  }

  static String? _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  static String _withoutTrailingSlash(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }
}
