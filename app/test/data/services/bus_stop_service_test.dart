import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/data/models/user_coordinates.dart';
import 'package:meubuzu/data/services/bus_stop_service.dart';

const _position = UserCoordinates(latitude: -5.165446, longitude: -42.791169);

const _csv =
    '"id","codigo","denominacao","endereco","lat","long","created_at","updated_at"\n'
    '1,"2362","T-SANTA FÉ","Rua B, Loteamento Mário Covas, Teresina - PI",-5.165446,-42.791169,"2019-10-09 14:03:26","2019-10-09 14:03:26"\n'
    '2,"1848","CONJUNTO BENTINHO 1","Rua Seis, 8831 - Angelim, Teresina - PI",-5.165446,-42.790369,"2019-10-09 14:03:26","2019-10-09 14:03:26"\n'
    '3,"1850","PARADA DISTANTE","Rua Distante",-5.165446,-42.786169,"2019-10-09 14:03:26","2019-10-09 14:03:26"\n'
    '4,"1851","PARADA INVÁLIDA","Rua Inválida",nao,-42.789,"2019-10-09 14:03:26","2019-10-09 14:03:26"\n';

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
  group('AssetBusStopService', () {
    test('retorna apenas paradas em até 500 metros', () async {
      final service = AssetBusStopService(bundle: _FakeAssetBundle(_csv));

      final stops = await service.findNearby(_position);

      expect(stops, hasLength(2));
      expect(stops.map((stop) => stop.id), ['1', '2']);
      expect(stops.first.code, '2362');
      expect(stops.first.name, 'T-SANTA FÉ');
      expect(
        stops.first.address,
        'Rua B, Loteamento Mário Covas, Teresina - PI',
      );
      expect(stops.first.latitude, -5.165446);
      expect(stops.first.longitude, -42.791169);
      expect(
        stops.every(
          (stop) =>
              stop.distanceInMetersTo(_position) <=
              nearbyBusStopsRadiusInMeters,
        ),
        isTrue,
      );
    });

    test('respeita um raio de busca customizado', () async {
      final service = AssetBusStopService(bundle: _FakeAssetBundle(_csv));

      final stops = await service.findNearby(
        _position,
        maxDistanceInMeters: 600,
      );

      expect(stops.map((stop) => stop.id), ['1', '2', '3']);
    });

    test('carrega o catálogo uma única vez', () async {
      final bundle = _FakeAssetBundle(_csv);
      final service = AssetBusStopService(bundle: bundle);

      await service.findNearby(_position);
      await service.findNearby(_position);

      expect(bundle.loadCount, 1);
    });

    test('falha quando o cabeçalho não tem as colunas esperadas', () async {
      final service = AssetBusStopService(
        bundle: _FakeAssetBundle('"id","codigo"\n1,"2362"\n'),
      );

      await expectLater(
        service.findNearby(_position),
        throwsA(isA<FormatException>()),
      );
    });

    test('catálogo vazio retorna lista vazia', () async {
      final service = AssetBusStopService(bundle: _FakeAssetBundle(''));

      final stops = await service.findNearby(_position);

      expect(stops, isEmpty);
    });

    test('busca paradas por código', () async {
      final service = AssetBusStopService(bundle: _FakeAssetBundle(_csv));

      final stops = await service.search('2362');

      expect(stops, hasLength(1));
      expect(stops.first.id, '1');
      expect(stops.first.code, '2362');
      expect(stops.first.name, 'T-SANTA FÉ');
    });

    test('busca paradas por denominação ignorando acentuação', () async {
      final service = AssetBusStopService(bundle: _FakeAssetBundle(_csv));

      final stops = await service.search('santa fé');

      expect(stops, hasLength(1));
      expect(stops.first.code, '2362');
    });

    test('busca paradas por endereço', () async {
      final service = AssetBusStopService(bundle: _FakeAssetBundle(_csv));

      final stops = await service.search('Rua B');

      expect(stops, hasLength(1));
      expect(stops.first.code, '2362');
    });

    test('retorna lista vazia para consulta sem resultados', () async {
      final service = AssetBusStopService(bundle: _FakeAssetBundle(_csv));

      final stops = await service.search('inexistente');

      expect(stops, isEmpty);
    });

    test('retorna lista vazia para consulta vazia', () async {
      final service = AssetBusStopService(bundle: _FakeAssetBundle(_csv));

      final stops = await service.search('   ');

      expect(stops, isEmpty);
    });
  });
}
