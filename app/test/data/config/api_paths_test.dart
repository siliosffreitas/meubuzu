import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/data/config/api_paths.dart';

void main() {
  group('ApiPaths', () {
    test('monta caminhos com a cidade explícita', () {
      expect(ApiPaths.city('teresina', 'lines'), '/v1/cities/teresina/lines');
      expect(ApiPaths.city('teresina', '/lines'), '/v1/cities/teresina/lines');
      expect(
        ApiPaths.city('teresina', 'lines/0301/stops'),
        '/v1/cities/teresina/lines/0301/stops',
      );
    });

    test('preserva o caminho vazio', () {
      expect(ApiPaths.city('teresina', ''), '/v1/cities/teresina/');
    });
  });
}
