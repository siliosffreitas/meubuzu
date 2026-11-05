import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/data/services/line_search_service.dart';

class _FakeAssetBundle extends AssetBundle {
  _FakeAssetBundle(this.content);

  final String content;

  @override
  Future<ByteData> load(String key) async {
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

    test('busca linhas por código', () async {
      final service = AssetLineSearchService(bundle: _FakeAssetBundle(catalog));

      final lines = await service.search('875');

      expect(lines, hasLength(1));
      expect(lines.first.id, '875A-10');
      expect(lines.first.name, 'PERDIZES ↔ TERMINAL LAPA');
      expect(lines.first.origin, 'PERDIZES');
      expect(lines.first.destination, 'TERMINAL LAPA');
    });

    test('busca linhas por nome ignorando acentuação e caixa alta', () async {
      final service = AssetLineSearchService(bundle: _FakeAssetBundle(catalog));

      final lines = await service.search('perdizes');

      expect(lines, hasLength(1));
      expect(lines.first.id, '875A-10');
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
        expect(lines.first.id, '46');
        expect(lines.first.name, 'MOCAMBINHO DUQUE DE CAXIAS');
        expect(lines.first.boardingCode, '0301');
      },
    );

    test('retorna lista vazia para consulta vazia', () async {
      final service = AssetLineSearchService(bundle: _FakeAssetBundle(catalog));

      final lines = await service.search('   ');

      expect(lines, isEmpty);
    });
  });
}
