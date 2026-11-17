import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/data/config/api_config.dart';

void main() {
  group('ApiConfig.configuredBaseUrl', () {
    test('API_BASE_URL tem precedência nas duas plataformas', () {
      expect(
        ApiConfig.configuredBaseUrl(
          isAndroid: true,
          generic: 'http://192.168.0.10:8000',
          android: 'http://10.0.2.2:8000',
          ios: 'http://127.0.0.1:8000',
        ),
        'http://192.168.0.10:8000',
      );
      expect(
        ApiConfig.configuredBaseUrl(
          isAndroid: false,
          generic: 'http://192.168.0.10:8000',
          android: 'http://10.0.2.2:8000',
          ios: 'http://127.0.0.1:8000',
        ),
        'http://192.168.0.10:8000',
      );
    });

    test('usa a variável da plataforma quando API_BASE_URL está vazia', () {
      expect(
        ApiConfig.configuredBaseUrl(
          isAndroid: true,
          generic: '',
          android: 'http://10.0.2.2:8000',
          ios: 'http://127.0.0.1:8000',
        ),
        'http://10.0.2.2:8000',
      );
      expect(
        ApiConfig.configuredBaseUrl(
          isAndroid: false,
          generic: '',
          android: 'http://10.0.2.2:8000',
          ios: 'http://127.0.0.1:8000',
        ),
        'http://127.0.0.1:8000',
      );
    });

    test('ignora espaços e trata tudo vazio como não configurado', () {
      expect(
        ApiConfig.configuredBaseUrl(
          isAndroid: false,
          generic: '  ',
          android: 'http://10.0.2.2:8000',
          ios: '  ',
        ),
        isNull,
      );
      expect(
        ApiConfig.configuredBaseUrl(
          isAndroid: true,
          generic: ' http://192.168.0.10:8000 ',
          android: 'http://10.0.2.2:8000',
          ios: '',
        ),
        'http://192.168.0.10:8000',
      );
    });
  });
}
