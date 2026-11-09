import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/data/services/tracking_service.dart';
import 'package:meubuzu/domain/models/line.dart';

class _FakeAssetBundle extends AssetBundle {
  _FakeAssetBundle(this.assets);

  final Map<String, String> assets;
  final List<String> loadedKeys = [];

  @override
  Future<ByteData> load(String key) async {
    loadedKeys.add(key);
    final content = assets[key];
    if (content == null) {
      throw FlutterError('Unable to load asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));
  }
}

const _sundayPath = 'assets/locations/positions_2023_06_04.csv';

/// Linha do arquivo de posições: label, codigoLinha, ônibus, geração, lat,
/// long, captura.
String _csvRow({
  String lineCode = '238',
  String busCode = '4171',
  String captured = '2023-06-04T11:58:00.000+0000',
  String generated = '2023-06-04T11:57:00.000+0000',
  String latitude = '-5.102443',
  String longitude = '-42.727275',
}) {
  return '03047,$lineCode,$busCode,$generated,$latitude,$longitude,$captured';
}

Line _line(String id) {
  return Line(
    id: id,
    name: 'LINHA $id',
    origin: 'ORIGEM',
    destination: 'DESTINO',
    boardingCode: '0100',
  );
}

void main() {
  group('AssetTrackingService', () {
    test('usa o arquivo do dia da semana da consulta', () async {
      for (final entry in AssetTrackingService.filesByWeekday.entries) {
        final bundle = _FakeAssetBundle({});
        final service = AssetTrackingService(bundle: bundle);
        // 05/06/2023 foi uma segunda-feira.
        final at = DateTime(2023, 6, 5 + entry.key - 1, 12);

        await service.findPositions([_line('238')], at: at);

        expect(bundle.loadedKeys, [
          'assets/locations/${entry.value}',
        ], reason: 'dia da semana ${entry.key}');
      }
    });

    test('domingo consulta positions_2023_06_04.csv', () async {
      final bundle = _FakeAssetBundle({
        _sundayPath: [_csvRow()].join('\n'),
      });
      final service = AssetTrackingService(bundle: bundle);

      final positions = await service.findPositions([
        _line('238'),
      ], at: DateTime(2023, 6, 4, 12));

      expect(bundle.loadedKeys.single, _sundayPath);
      expect(positions, hasLength(1));
      expect(positions.single.bus.code, '4171');
      expect(positions.single.latitude, -5.102443);
      expect(positions.single.longitude, -42.727275);
      expect(positions.single.capturedAt, DateTime.utc(2023, 6, 4, 11, 58));
    });

    test('aceita at por parâmetro e ignora o relógio', () async {
      final bundle = _FakeAssetBundle({});
      final service = AssetTrackingService(
        bundle: bundle,
        // Segunda-feira: não deve ser usado por causa do at.
        clock: () => DateTime(2023, 6, 5, 12),
      );

      await service.findPositions([_line('238')], at: DateTime(2023, 6, 4, 12));

      expect(bundle.loadedKeys.single, _sundayPath);
    });

    test('retorna apenas capturas dos últimos 5 minutos', () async {
      final bundle = _FakeAssetBundle({
        _sundayPath: [
          _csvRow(busCode: '1', captured: '2023-06-04T11:54:59.000+0000'),
          _csvRow(busCode: '2', captured: '2023-06-04T11:55:00.000+0000'),
          _csvRow(busCode: '3', captured: '2023-06-04T11:59:59.000+0000'),
          _csvRow(busCode: '4', captured: '2023-06-04T12:00:00.000+0000'),
          _csvRow(busCode: '5', captured: '2023-06-04T12:00:01.000+0000'),
        ].join('\n'),
      });
      final service = AssetTrackingService(bundle: bundle);

      final positions = await service.findPositions([
        _line('238'),
      ], at: DateTime(2023, 6, 4, 12));

      expect(positions.map((position) => position.bus.code), ['2', '3', '4']);
    });

    test('mantém apenas a captura mais recente de cada ônibus', () async {
      final bundle = _FakeAssetBundle({
        _sundayPath: [
          _csvRow(busCode: '4171', captured: '2023-06-04T11:56:00.000+0000'),
          _csvRow(busCode: '4171', captured: '2023-06-04T11:58:00.000+0000'),
          _csvRow(busCode: '5096', captured: '2023-06-04T11:57:00.000+0000'),
        ].join('\n'),
      });
      final service = AssetTrackingService(bundle: bundle);

      final positions = await service.findPositions([
        _line('238'),
      ], at: DateTime(2023, 6, 4, 12));

      expect(positions, hasLength(2));
      final first = positions.singleWhere((p) => p.bus.code == '4171');
      expect(first.capturedAt, DateTime.utc(2023, 6, 4, 11, 58));
    });

    test('filtra apenas as linhas consultadas', () async {
      final bundle = _FakeAssetBundle({
        _sundayPath: [
          _csvRow(lineCode: '238', busCode: '4171'),
          _csvRow(lineCode: '30', busCode: '5096'),
        ].join('\n'),
      });
      final service = AssetTrackingService(bundle: bundle);

      final positions = await service.findPositions([
        _line('238'),
      ], at: DateTime(2023, 6, 4, 12));

      expect(positions.map((position) => position.bus.code), ['4171']);
    });

    test('compara códigos de linha ignorando zeros à esquerda', () async {
      final bundle = _FakeAssetBundle({
        _sundayPath: _csvRow(lineCode: '238', busCode: '4171'),
      });
      final service = AssetTrackingService(bundle: bundle);

      final positions = await service.findPositions([
        _line('0238'),
      ], at: DateTime(2023, 6, 4, 12));

      expect(positions, hasLength(1));
    });

    test('ignora linhas malformadas do arquivo', () async {
      final bundle = _FakeAssetBundle({
        _sundayPath: [
          '03047,238',
          _csvRow(busCode: '4171', latitude: 'invalida'),
          _csvRow(busCode: '5096', captured: 'sem data'),
          _csvRow(busCode: '4688'),
        ].join('\n'),
      });
      final service = AssetTrackingService(bundle: bundle);

      final positions = await service.findPositions([
        _line('238'),
      ], at: DateTime(2023, 6, 4, 12));

      expect(positions.map((position) => position.bus.code), ['4688']);
    });

    test('retorna vazio sem ler o asset quando não há linhas', () async {
      final bundle = _FakeAssetBundle({});
      final service = AssetTrackingService(bundle: bundle);

      final positions = await service.findPositions(
        const [],
        at: DateTime(2023, 6, 4, 12),
      );

      expect(positions, isEmpty);
      expect(bundle.loadedKeys, isEmpty);
    });

    test('retorna vazio quando o arquivo do dia não existe', () async {
      final service = AssetTrackingService(bundle: _FakeAssetBundle({}));

      final positions = await service.findPositions([
        _line('238'),
      ], at: DateTime(2023, 6, 4, 12));

      expect(positions, isEmpty);
    });

    test('lê o arquivo uma única vez entre consultas', () async {
      final bundle = _FakeAssetBundle({_sundayPath: _csvRow(busCode: '4171')});
      final service = AssetTrackingService(bundle: bundle);

      await service.findPositions([_line('238')], at: DateTime(2023, 6, 4, 12));
      await service.findPositions([_line('238')], at: DateTime(2023, 6, 4, 13));

      expect(bundle.loadedKeys, [_sundayPath]);
    });
  });
}
