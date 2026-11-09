import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:meubuzu/domain/models/bus.dart';
import 'package:meubuzu/domain/models/bus_position.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/domain/models/tracked_line.dart';
import 'package:meubuzu/ui/core/extensions/line_map_color.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_tracking_markers.dart';

const _line = Line(
  id: '46',
  name: 'MOCAMBINHO DUQUE DE CAXIAS',
  origin: 'MOCAMBINHO',
  destination: 'MOCAMBINHO',
  boardingCode: '0301',
);

const _otherLine = Line(
  id: '47',
  name: 'OUTRA LINHA',
  origin: 'CENTRO',
  destination: 'SHOPPING',
  boardingCode: '0302',
);

BusPosition _position(
  String busCode, {
  double latitude = -5.1,
  double longitude = -42.8,
  DateTime? capturedAt,
}) {
  return BusPosition(
    bus: Bus(code: busCode),
    latitude: latitude,
    longitude: longitude,
    capturedAt: capturedAt ?? DateTime.utc(2023, 6, 4, 11, 58),
  );
}

TrackedLine _tracked(Line line, List<BusPosition> positions) {
  return TrackedLine(line: line, route: null, busPositions: positions);
}

void main() {
  // Necessário para desenhar os ícones com Canvas nos testes.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildTrackingBusMarkers', () {
    test('não cria marcadores sem linhas acompanhadas', () {
      expect(buildTrackingBusMarkers(const []), isEmpty);
    });

    test('não cria marcadores quando a linha não tem posições', () {
      expect(buildTrackingBusMarkers([_tracked(_line, const [])]), isEmpty);
    });

    test('cria um marcador por ônibus com posição, id e âncora', () {
      final markers = buildTrackingBusMarkers([
        _tracked(_line, [
          _position('4171', latitude: -5.102443, longitude: -42.727275),
          _position('5096', latitude: -5.2, longitude: -42.9),
        ]),
      ]);

      expect(markers, hasLength(2));

      final first = markers.singleWhere(
        (marker) => marker.markerId.value == 'bus-0301-4171',
      );
      expect(first.position.latitude, -5.102443);
      expect(first.position.longitude, -42.727275);
      expect(first.anchor, const Offset(0.5, 0.5));
      expect(first.zIndexInt, 1);

      expect(
        markers.map((marker) => marker.markerId.value),
        contains('bus-0301-5096'),
      );
    });

    test(
      'não repete o id quando o mesmo ônibus aparece em linhas diferentes',
      () {
        final markers = buildTrackingBusMarkers([
          _tracked(_line, [_position('4171')]),
          _tracked(_otherLine, [_position('4171')]),
        ]);

        expect(markers, hasLength(2));
        expect(
          markers.map((marker) => marker.markerId.value),
          containsAll(['bus-0301-4171', 'bus-0302-4171']),
        );
      },
    );

    test('usa o ícone gerado para a cor da linha', () {
      final icon = BitmapDescriptor.defaultMarker;
      final colors = <Color>[];

      final markers = buildTrackingBusMarkers(
        [
          _tracked(_line, [_position('4171')]),
        ],
        iconFor: (color) {
          colors.add(color);
          return icon;
        },
      );

      expect(colors, [_line.mapColor]);
      expect(markers.single.icon, same(icon));
    });

    test('usa o ícone padrão com a matiz da linha como fallback', () {
      final markers = buildTrackingBusMarkers([
        _tracked(_line, [_position('4171')]),
      ], iconFor: (_) => null);

      // ignore: deprecated_member_use
      expect(markers.single.icon.toJson(), [
        'defaultMarker',
        busMarkerFallbackHue(_line.mapColor),
      ]);
    });

    test('monta a janela de informações com linha, ônibus e horário', () {
      final markers = buildTrackingBusMarkers([
        _tracked(_line, [
          _position('4171', capturedAt: DateTime.utc(2023, 6, 4, 9, 5)),
        ]),
      ]);

      expect(markers.single.infoWindow.title, 'Linha 0301 • Ônibus 4171');
      expect(markers.single.infoWindow.snippet, 'Atualizado às 09:05');
    });
  });

  group('TrackingBusMarkerIcons', () {
    test('gera o ícone e o mantém no cache por cor', () async {
      final icons = TrackingBusMarkerIcons();
      expect(icons[Colors.red], isNull);

      expect(await icons.ensure([Colors.red]), isTrue);

      final icon = icons[Colors.red];
      expect(icon, isNotNull);
      expect(await icons.ensure([Colors.red]), isFalse);
      expect(icons[Colors.red], same(icon));
    });

    test('gera ícones diferentes para cores diferentes', () async {
      final icons = TrackingBusMarkerIcons();

      await icons.ensure([Colors.red, Colors.blue]);

      expect(icons[Colors.red], isNotNull);
      expect(icons[Colors.blue], isNotNull);
      expect(icons[Colors.red], isNot(same(icons[Colors.blue])));
    });

    test('não gera duas vezes a mesma cor em chamadas concorrentes', () async {
      final icons = TrackingBusMarkerIcons();

      final first = icons.ensure([Colors.red]);
      final second = icons.ensure([Colors.red]);

      expect(await first, isTrue);
      expect(await second, isFalse);
      expect(icons[Colors.red], isNotNull);
    });
  });
}
