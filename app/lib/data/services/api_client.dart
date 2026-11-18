import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/contracts/contracts.dart';

/// Erro devolvido pela API no formato Problem Details (RFC 9457).
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.detail,
    this.retryAfter,
  });

  final int statusCode;

  /// Código estável para o app decidir o que fazer, nunca o texto.
  final String code;
  final String detail;

  /// Segundos até tentar novamente, quando a API informa.
  final Duration? retryAfter;

  @override
  String toString() => 'ApiException($statusCode, $code): $detail';
}

/// Falha de transporte: sem conexão, DNS ou timeout.
class NetworkException implements Exception {
  const NetworkException([
    this.message = 'Não foi possível falar com o servidor.',
  ]);

  final String message;

  @override
  String toString() => 'NetworkException: $message';
}

/// Cliente HTTP mínimo, com JSON e tratamento de erro da API.
class ApiClient implements Service {
  ApiClient(this._baseUrl, {http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _httpClient;

  static const _timeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> get(String path, {String? accessToken}) async {
    final response = await _run(
      () => _httpClient.get(_uri(path), headers: _headers(accessToken)),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    String? accessToken,
  }) async {
    final response = await _run(
      () => _httpClient.post(
        _uri(path),
        headers: _headers(accessToken, hasBody: body != null),
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Object? body,
    String? accessToken,
  }) async {
    final response = await _run(
      () => _httpClient.put(
        _uri(path),
        headers: _headers(accessToken, hasBody: body != null),
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> delete(String path, {String? accessToken}) async {
    final response = await _run(
      () => _httpClient.delete(_uri(path), headers: _headers(accessToken)),
    );
    return _decodeResponse(response);
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Map<String, String> _headers(String? accessToken, {bool hasBody = false}) {
    return {
      'Accept': 'application/json',
      if (hasBody) 'Content-Type': 'application/json',
      if (accessToken != null && accessToken.isNotEmpty)
        'Authorization': 'Bearer $accessToken',
    };
  }

  Future<http.Response> _run(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException {
      throw const NetworkException('O servidor demorou demais para responder.');
    } on http.ClientException catch (error) {
      throw NetworkException(error.message);
    } on SocketException catch (error) {
      throw NetworkException(error.message);
    } on HttpException catch (error) {
      throw NetworkException(error.message);
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final body = response.body.trim();
    final decoded = body.isEmpty ? null : _tryDecode(body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded is Map<String, dynamic> ? decoded : const {};
    }

    final problem = decoded is Map<String, dynamic> ? decoded : const {};
    final retryAfterSeconds = problem['retryAfter'];

    throw ApiException(
      statusCode: response.statusCode,
      code: problem['code'] as String? ?? 'http_${response.statusCode}',
      detail:
          problem['detail'] as String? ??
          'A requisição não pôde ser concluída.',
      retryAfter: retryAfterSeconds is num
          ? Duration(seconds: retryAfterSeconds.round())
          : null,
    );
  }

  Object? _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }
}
