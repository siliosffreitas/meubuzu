import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/data/services/line_search_service.dart';

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

void main() {
  group('AssetLineSearchService', () {
    final catalog = '''
codigoLinha,nomeLinha,getOrigemIda,destinoIda,sgLinha
875A-10,PERDIZES ↔ TERMINAL LAPA,PERDIZES,TERMINAL LAPA,0001
8000-1,VILA BANDEIRANTE-PLANALTO ININGA,VILA BANDEIRANTE,VILA BANDEIRANTE,0402
46,MOCAMBINHO DUQUE DE CAXIAS,MOCAMBINHO,MOCAMBINHO,0301
''';

    test('busca linhas pelo sgLinha', () async {
      final service = AssetLineSearchService(bundle: _FakeAssetBundle(catalog));

      final lines = await service.search('0001');

      expect(lines, hasLength(1));
      expect(lines.first.boardingCode, '0001');
      expect(lines.first.name, 'PERDIZES ↔ TERMINAL LAPA');
      expect(lines.first.origin, 'PERDIZES');
      expect(lines.first.destination, 'TERMINAL LAPA');
    });

    test('busca linhas por nome ignorando acentuação e caixa alta', () async {
      final service = AssetLineSearchService(bundle: _FakeAssetBundle(catalog));

      final lines = await service.search('perdizes');

      expect(lines, hasLength(1));
      expect(lines.first.boardingCode, '0001');
    });

    test('retorna lista vazia para consulta sem resultados', () async {
      final service = AssetLineSearchService(bundle: _FakeAssetBundle(catalog));

      final lines = await service.search('inexistente');

      expect(lines, isEmpty);
    });

    test(
      'busca por código de embarque sem exigir correspondência exata',
      () async {
        final service = AssetLineSearchService(
          bundle: _FakeAssetBundle(catalog),
        );

        final lines = await service.search('301');

        expect(lines, hasLength(1));
        expect(lines.first.boardingCode, '0301');
        expect(lines.first.name, 'MOCAMBINHO DUQUE DE CAXIAS');
        expect(lines.first.boardingCode, '0301');
      },
    );

    test('retorna lista vazia para consulta vazia', () async {
      final service = AssetLineSearchService(bundle: _FakeAssetBundle(catalog));

      final lines = await service.search('   ');

      expect(lines, isEmpty);
    });

    test('busca linhas pelos códigos preservando a ordem recebida', () async {
      final service = AssetLineSearchService(bundle: _FakeAssetBundle(catalog));

      final lines = await service.findByCodes(['0402', '0001']);

      expect(lines.map((line) => line.boardingCode), ['0402', '0001']);
    });

    test('codigoLinha não resolve linha na busca pública', () async {
      final service = AssetLineSearchService(bundle: _FakeAssetBundle(catalog));

      final lines = await service.findByCodes(['46', '0301']);

      expect(lines.map((line) => line.boardingCode), ['0301']);
    });

    test('ignora códigos vazios, repetidos e desconhecidos', () async {
      final service = AssetLineSearchService(bundle: _FakeAssetBundle(catalog));

      final lines = await service.findByCodes([' 0402 ', '0402', '', '9999']);

      expect(lines, hasLength(1));
      expect(lines.first.boardingCode, '0402');
    });

    test('linhas sem sgLinha não entram no catálogo', () async {
      final service = AssetLineSearchService(
        bundle: _FakeAssetBundle(
          'codigoLinha,nomeLinha,getOrigemIda,destinoIda,sgLinha\n'
          '46,SEM CODIGO,Origem,Destino,\n',
        ),
      );

      expect(await service.search('sem codigo'), isEmpty);
      expect(await service.findByCodes(['46']), isEmpty);
    });

    test('lista vazia retorna lista vazia sem carregar o asset', () async {
      final bundle = _FakeAssetBundle(catalog);
      final service = AssetLineSearchService(bundle: bundle);

      final lines = await service.findByCodes([]);

      expect(lines, isEmpty);
      expect(bundle.loadCount, 0);
    });

    test(
      'carrega o asset uma única vez ao buscar por nome e por código',
      () async {
        final bundle = _FakeAssetBundle(catalog);
        final service = AssetLineSearchService(bundle: bundle);

        await service.search('perdizes');
        await service.findByCodes(['0001']);
        await service.search('vila');

        expect(bundle.loadCount, 1);
      },
    );
  });
}
