import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:meubuzu/domain/models/bus.dart';
import 'package:meubuzu/domain/models/bus_position.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/domain/models/tracked_line.dart';
import 'package:meubuzu/ui/core/extensions/line_map_color.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_tracking_directions.dart';
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

    test('não cria seta quando a direção ainda é desconhecida', () {
      final markers = buildTrackingBusMarkers([
        _tracked(_line, [_position('4171')]),
      ], arrowIconFor: (_) => BitmapDescriptor.defaultMarker);

      expect(markers, hasLength(1));
      expect(
        markers.every(
          (marker) => !marker.markerId.value.startsWith('bus-arrow-'),
        ),
        isTrue,
      );
    });

    test('cria a seta na direção do movimento sobre o ônibus', () {
      final position = _position('4171');
      final tracked = _tracked(_line, [position]);
      final arrowIcon = BitmapDescriptor.defaultMarker;

      final markers = buildTrackingBusMarkers(
        [tracked],
        bearings: {trackedBusKey(tracked, position): 135},
        arrowIconFor: (_) => arrowIcon,
      );

      expect(markers, hasLength(2));

      final arrow = markers.singleWhere(
        (marker) => marker.markerId.value == 'bus-arrow-0301-4171',
      );
      expect(arrow.position.latitude, position.latitude);
      expect(arrow.position.longitude, position.longitude);
      expect(arrow.rotation, 135);
      expect(arrow.anchor, const Offset(0.5, 1));
      expect(arrow.zIndexInt, 2);
      expect(arrow.icon, same(arrowIcon));
      expect(arrow.infoWindow.title, isNull);
    });

    test('não cria a seta enquanto o ícone dela não está pronto', () {
      final position = _position('4171');
      final tracked = _tracked(_line, [position]);

      final markers = buildTrackingBusMarkers(
        [tracked],
        bearings: {trackedBusKey(tracked, position): 90},
        arrowIconFor: (_) => null,
      );

      expect(markers, hasLength(1));
    });

    test('cria setas apenas para os ônibus com direção conhecida', () {
      final withBearing = _position('4171');
      final withoutBearing = _position('5096');
      final tracked = _tracked(_line, [withBearing, withoutBearing]);

      final markers = buildTrackingBusMarkers(
        [tracked],
        bearings: {trackedBusKey(tracked, withBearing): 0},
        arrowIconFor: (_) => BitmapDescriptor.defaultMarker,
      );

      expect(
        markers.where(
          (marker) => marker.markerId.value.startsWith('bus-arrow-'),
        ),
        hasLength(1),
      );
      expect(markers, hasLength(3));
    });

    test('usa a posição animada no ônibus e na seta', () {
      final position = _position('4171');
      final tracked = _tracked(_line, [position]);
      const animated = LatLng(-5.095, -42.795);

      final markers = buildTrackingBusMarkers(
        [tracked],
        positions: {trackedBusKey(tracked, position): animated},
        bearings: {trackedBusKey(tracked, position): 90},
        arrowIconFor: (_) => BitmapDescriptor.defaultMarker,
      );

      final bus = markers.singleWhere(
        (marker) => marker.markerId.value == 'bus-0301-4171',
      );
      final arrow = markers.singleWhere(
        (marker) => marker.markerId.value == 'bus-arrow-0301-4171',
      );

      expect(bus.position.latitude, animated.latitude);
      expect(bus.position.longitude, animated.longitude);
      expect(arrow.position.latitude, animated.latitude);
      expect(arrow.position.longitude, animated.longitude);
    });
  });

  group('TrackingBusMarkerIcons', () {
    test('gera o ícone e o mantém no cache por cor', () async {
      final icons = TrackingBusMarkerIcons();
      expect(icons[Colors.red], isNull);
      expect(icons.arrow(Colors.red), isNull);

      expect(await icons.ensure([Colors.red]), isTrue);

      final icon = icons[Colors.red];
      final arrow = icons.arrow(Colors.red);
      expect(icon, isNotNull);
      expect(arrow, isNotNull);
      expect(arrow, isNot(same(icon)));
      expect(await icons.ensure([Colors.red]), isFalse);
      expect(icons[Colors.red], same(icon));
      expect(icons.arrow(Colors.red), same(arrow));
    });

    test('gera ícones diferentes para cores diferentes', () async {
      final icons = TrackingBusMarkerIcons();

      await icons.ensure([Colors.red, Colors.blue]);

      expect(icons[Colors.red], isNotNull);
      expect(icons[Colors.blue], isNotNull);
      expect(icons[Colors.red], isNot(same(icons[Colors.blue])));
      expect(icons.arrow(Colors.red), isNotNull);
      expect(icons.arrow(Colors.blue), isNotNull);
      expect(icons.arrow(Colors.red), isNot(same(icons.arrow(Colors.blue))));
    });

    test('não gera duas vezes a mesma cor em chamadas concorrentes', () async {
      final icons = TrackingBusMarkerIcons();

      final first = icons.ensure([Colors.red]);
      final second = icons.ensure([Colors.red]);

      expect(await first, isTrue);
      expect(await second, isFalse);
      expect(icons[Colors.red], isNotNull);
      expect(icons.arrow(Colors.red), isNotNull);
    });
  });
}
