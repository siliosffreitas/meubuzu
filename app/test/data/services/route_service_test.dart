import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/data/services/route_service.dart';

class _FakeAssetBundle extends AssetBundle {
  _FakeAssetBundle(this.assets);

  final Map<String, String> assets;
  int loadCount = 0;

  @override
  Future<ByteData> load(String key) async {
    loadCount++;
    final content = assets[key];
    if (content == null) {
      throw FlutterError('Unable to load asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));
  }
}

void main() {
  group('AssetRouteService', () {
    test('lê as coordenadas do traçado da linha', () async {
      final bundle = _FakeAssetBundle({
        'assets/routes/0301.csv': '-5.1,-42.8\n-5.2,-42.9\n',
      });
      final service = AssetRouteService(bundle: bundle);

      final route = await service.findRoute('0301');

      expect(route, isNotNull);
      expect(route!.positions, hasLength(2));
      expect(route.positions.first.latitude, -5.1);
      expect(route.positions.first.longitude, -42.8);
      expect(route.positions.last.latitude, -5.2);
      expect(route.positions.last.longitude, -42.9);
    });

    test('aceita coordenadas separadas por CRLF', () async {
      final service = AssetRouteService(
        bundle: _FakeAssetBundle({
          'assets/routes/A131.csv': '-5.05,-42.83\r\n-5.06,-42.84\r\n',
        }),
      );

      final route = await service.findRoute('A131');

      expect(route!.positions, hasLength(2));
    });

    test('remove espaços e ignora linhas inválidas', () async {
      final service = AssetRouteService(
        bundle: _FakeAssetBundle({
          'assets/routes/0004.csv':
              ' -5.1 , -42.8 \n'
              '\n'
              'invalido,coordenada\n'
              '-5.2\n'
              '-5.3,-42.9\n',
        }),
      );

      final route = await service.findRoute('0004');

      expect(route!.positions, hasLength(2));
      expect(route.positions.first.latitude, -5.1);
      expect(route.positions.last.longitude, -42.9);
    });

    test('retorna null quando a linha não possui traçado', () async {
      final service = AssetRouteService(bundle: _FakeAssetBundle({}));

      final route = await service.findRoute('9999');

      expect(route, isNull);
    });

    test('retorna null para traçado sem coordenadas válidas', () async {
      final service = AssetRouteService(
        bundle: _FakeAssetBundle({'assets/routes/9999.csv': '\n\n'}),
      );

      final route = await service.findRoute('9999');

      expect(route, isNull);
    });

    test('código vazio não carrega o asset', () async {
      final bundle = _FakeAssetBundle({});
      final service = AssetRouteService(bundle: bundle);

      final route = await service.findRoute('   ');

      expect(route, isNull);
      expect(bundle.loadCount, 0);
    });

    test('carrega cada traçado uma única vez', () async {
      final bundle = _FakeAssetBundle({
        'assets/routes/0301.csv': '-5.1,-42.8\n',
      });
      final service = AssetRouteService(bundle: bundle);

      await service.findRoute('0301');
      await service.findRoute('0301');

      expect(bundle.loadCount, 1);
    });

    test('remove barra final do diretório de assets', () async {
      final bundle = _FakeAssetBundle({
        'assets/routes/0301.csv': '-5.1,-42.8\n',
      });
      final service = AssetRouteService(
        bundle: bundle,
        assetDirectory: 'assets/routes/',
      );

      final route = await service.findRoute('0301');

      expect(route!.positions, hasLength(1));
    });
  });
}
