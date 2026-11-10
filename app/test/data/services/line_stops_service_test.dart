import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/data/services/line_stops_service.dart';

class _FakeAssetBundle extends AssetBundle {
  _FakeAssetBundle(this.content);

  final String content;
  int loadCount = 0;

  @override
  Future<ByteData> load(String key) async {
    loadCount++;
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));
  }
}

const _json = '''
{
  "505": "174,175,176",
  "0002": " 857 , 920 ,",
  "T531": "",
  "0301": "174, 175, 999"
}
''';

void main() {
  group('AssetLineStopsService', () {
    test('retorna os códigos de paradas da linha', () async {
      final service = AssetLineStopsService(bundle: _FakeAssetBundle(_json));

      final codes = await service.findStopCodesForLine('505');

      expect(codes, ['174', '175', '176']);
    });

    test('remove espaços e códigos vazios', () async {
      final service = AssetLineStopsService(bundle: _FakeAssetBundle(_json));

      final codes = await service.findStopCodesForLine('0002');

      expect(codes, ['857', '920']);
    });

    test('linha sem paradas retorna lista vazia', () async {
      final service = AssetLineStopsService(bundle: _FakeAssetBundle(_json));

      final codes = await service.findStopCodesForLine('T531');

      expect(codes, isEmpty);
    });

    test('linha inexistente retorna lista vazia', () async {
      final service = AssetLineStopsService(bundle: _FakeAssetBundle(_json));

      final codes = await service.findStopCodesForLine('inexistente');

      expect(codes, isEmpty);
    });

    test('código vazio não carrega o asset', () async {
      final bundle = _FakeAssetBundle(_json);
      final service = AssetLineStopsService(bundle: bundle);

      final codes = await service.findStopCodesForLine('   ');

      expect(codes, isEmpty);
      expect(bundle.loadCount, 0);
    });

    test('carrega o asset uma única vez', () async {
      final bundle = _FakeAssetBundle(_json);
      final service = AssetLineStopsService(bundle: bundle);

      await service.findStopCodesForLine('505');
      await service.findStopCodesForLine('0002');

      expect(bundle.loadCount, 1);
    });

    test('retorna as linhas que passam pela parada', () async {
      final service = AssetLineStopsService(bundle: _FakeAssetBundle(_json));

      final codes = await service.findLineCodesForStop('174');

      expect(codes, ['505', '0301']);
    });

    test('remove espaços do código da parada', () async {
      final service = AssetLineStopsService(bundle: _FakeAssetBundle(_json));

      final codes = await service.findLineCodesForStop(' 857 ');

      expect(codes, ['0002']);
    });

    test('parada inexistente retorna lista vazia', () async {
      final service = AssetLineStopsService(bundle: _FakeAssetBundle(_json));

      final codes = await service.findLineCodesForStop('inexistente');

      expect(codes, isEmpty);
    });

    test('código de parada vazio não carrega o asset', () async {
      final bundle = _FakeAssetBundle(_json);
      final service = AssetLineStopsService(bundle: bundle);

      final codes = await service.findLineCodesForStop('   ');

      expect(codes, isEmpty);
      expect(bundle.loadCount, 0);
    });

    test(
      'carrega o asset uma única vez ao consultar linhas e paradas',
      () async {
        final bundle = _FakeAssetBundle(_json);
        final service = AssetLineStopsService(bundle: bundle);

        await service.findStopCodesForLine('505');
        await service.findLineCodesForStop('174');

        expect(bundle.loadCount, 1);
      },
    );
  });
}
