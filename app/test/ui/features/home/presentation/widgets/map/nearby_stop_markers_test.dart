import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:meubuzu/domain/models/bus_stop.dart';
import 'package:meubuzu/ui/core/theme/app_colors.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/nearby_stop_markers.dart';

const _busStop = BusStop(
  id: '1',
  code: '2362',
  name: 'T-SANTA FÉ',
  address: 'Rua B, Teresina - PI',
  latitude: -5.165446,
  longitude: -42.791169,
);

const _otherBusStop = BusStop(
  id: '2',
  code: '2363',
  name: 'SHOPPING',
  address: 'Av. C, Teresina - PI',
  latitude: -5.165,
  longitude: -42.792,
);

void main() {
  // Necessário para desenhar os ícones com Canvas nos testes.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildNearbyStopMarkers', () {
    test('cria um marcador com posição e informações da parada', () {
      final markers = buildNearbyStopMarkers(const [_busStop]);

      expect(markers, hasLength(1));
      final marker = markers.single;
      expect(marker.markerId.value, 'stop-1');
      expect(marker.position.latitude, _busStop.latitude);
      expect(marker.position.longitude, _busStop.longitude);
      expect(marker.infoWindow.title, _busStop.name);
      expect(marker.infoWindow.snippet, _busStop.address);
      expect(marker.anchor, const Offset(0.5, 1.0));
    });

    test('usa o ícone e a âncora informados para cada parada', () {
      const icon = BitmapDescriptor.defaultMarker;
      const anchor = Offset(0.2, 0.7);

      final marker = buildNearbyStopMarkers(
        const [_busStop],
        iconFor: (_) => icon,
        anchorFor: (_) => anchor,
      ).single;

      expect(marker.icon, same(icon));
      expect(marker.anchor, anchor);
    });

    test('não cria marcadores quando não há paradas', () {
      expect(buildNearbyStopMarkers(const []), isEmpty);
    });

    test('aciona o callback ao tocar no marcador da parada', () {
      BusStop? tapped;
      final marker = buildNearbyStopMarkers(const [
        _busStop,
      ], onTap: (stop) => tapped = stop).single;

      expect(marker.onTap, isNotNull);
      marker.onTap!();

      expect(tapped, _busStop);
    });
  });

  group('paintNearbyStopMarker', () {
    test(
      'desenha apenas a borda na cor do app, com centro transparente',
      () async {
        const canvasSize = 40;
        const center = Offset(canvasSize / 2, canvasSize / 2);
        const diameter = 20.0;
        const strokeWidth = 4.0;

        final recorder = ui.PictureRecorder();
        paintNearbyStopMarker(
          ui.Canvas(recorder),
          center: center,
          diameter: diameter,
          strokeWidth: strokeWidth,
        );
        final picture = recorder.endRecording();
        addTearDown(picture.dispose);

        final image = await picture.toImage(canvasSize, canvasSize);
        addTearDown(image.dispose);

        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final bytes = data!.buffer.asUint8List();

        int channelAt(Offset position, int channel) =>
            bytes[(position.dy.toInt() * canvasSize + position.dx.toInt()) * 4 +
                channel];

        // O centro fica transparente.
        expect(channelAt(center, 3), 0);

        // A borda usa a cor principal do app.
        final borderPoint =
            center + const Offset(diameter / 2 - strokeWidth / 2, 0);
        final argb = AppColors.primary.toARGB32();
        expect(channelAt(borderPoint, 3), 255);
        expect(channelAt(borderPoint, 0), (argb >> 16) & 0xFF);
        expect(channelAt(borderPoint, 1), (argb >> 8) & 0xFF);
        expect(channelAt(borderPoint, 2), argb & 0xFF);
      },
    );
  });

  group('paintNearbyStopMarkerIcon', () {
    test(
      'desenha o nome verde com borda branca, sem fundo atrás dele',
      () async {
        final recorder = ui.PictureRecorder();
        final icon = paintNearbyStopMarkerIcon(
          ui.Canvas(recorder),
          _busStop.name,
        );
        final picture = recorder.endRecording();
        addTearDown(picture.dispose);

        final image = await picture.toImage(
          icon.size.width.ceil(),
          icon.size.height.ceil(),
        );
        addTearDown(image.dispose);

        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final bytes = data!.buffer.asUint8List();
        final width = icon.size.width.ceil();

        // Região do nome: acima e à direita do anel.
        final ringTop = icon.ringCenter.dy - nearbyStopMarkerDiameter / 2;
        final ringRight = icon.ringCenter.dx + nearbyStopMarkerDiameter / 2;
        final primary = AppColors.primary.toARGB32();

        var paintedPixels = 0;
        var regionPixels = 0;
        var greenPixels = 0;
        var whitePixels = 0;
        for (var y = 0; y < ringTop.ceil(); y++) {
          for (var x = ringRight.ceil(); x < width; x++) {
            final index = (y * width + x) * 4;
            regionPixels++;

            final alpha = bytes[index + 3];
            if (alpha == 0) {
              continue;
            }
            paintedPixels++;

            // Sem anti-aliasing, os píxeis do nome são a letra verde ou a
            // borda branca ao redor dela.
            final red = bytes[index];
            final green = bytes[index + 1];
            final blue = bytes[index + 2];
            if (alpha == 255 &&
                red == ((primary >> 16) & 0xFF) &&
                green == ((primary >> 8) & 0xFF) &&
                blue == (primary & 0xFF)) {
              greenPixels++;
            } else if (alpha == 255 &&
                red == 255 &&
                green == 255 &&
                blue == 255) {
              whitePixels++;
            }
          }
        }

        // As letras verdes e a borda branca aparecem na região...
        expect(greenPixels, greaterThan(0));
        expect(whitePixels, greaterThan(0));
        // ...ocupando só o desenho do nome, sem um retângulo de fundo.
        expect(paintedPixels, greaterThan(0));
        expect(paintedPixels / regionPixels, lessThan(0.6));
      },
    );
  });

  group('buildNearbyStopLabelFillStyle', () {
    test('preenche as letras com a cor principal do app', () {
      final style = buildNearbyStopLabelFillStyle();

      expect(style.color?.toARGB32(), AppColors.primary.toARGB32());
      expect(style.foreground, isNull);
      expect(style.fontSize, nearbyStopLabelTextSize);
    });
  });

  group('buildNearbyStopLabelStrokeStyle', () {
    test('desenha a borda branca apenas com contorno', () {
      final style = buildNearbyStopLabelStrokeStyle();
      final foreground = style.foreground;

      expect(foreground, isNotNull);
      expect(foreground!.style, ui.PaintingStyle.stroke);
      expect(foreground.color.toARGB32(), 0xFFFFFFFF);
      expect(
        foreground.strokeWidth,
        moreOrLessEquals(nearbyStopLabelStrokeWidth, epsilon: 1e-6),
      );

      // Sem `color`, o preenchimento fica por conta do estilo de fundo.
      expect(style.color, isNull);
    });
  });

  group('NearbyStopMarkerIcons', () {
    test('gera o ícone com a âncora no centro do anel', () async {
      final icons = NearbyStopMarkerIcons();
      expect(icons.iconFor(_busStop.name), isNull);
      expect(icons.anchorFor(_busStop.name), isNull);

      expect(await icons.ensure([_busStop.name]), isTrue);

      expect(icons.iconFor(_busStop.name), isNotNull);
      final anchor = icons.anchorFor(_busStop.name);
      expect(anchor, isNotNull);

      // O anel fica no canto inferior esquerdo, com o nome acima e à direita.
      expect(anchor!.dx, greaterThan(0));
      expect(anchor.dx, lessThan(0.5));
      expect(anchor.dy, greaterThan(0.5));
      expect(anchor.dy, lessThan(1));
    });

    test('gera um ícone por nome e reaproveita os já prontos', () async {
      final icons = NearbyStopMarkerIcons();

      await icons.ensure([_busStop.name, _otherBusStop.name]);

      final first = icons.iconFor(_busStop.name);
      expect(first, isNotNull);
      expect(icons.iconFor(_otherBusStop.name), isNotNull);
      expect(icons.iconFor(_otherBusStop.name), isNot(same(first)));

      expect(await icons.ensure([_busStop.name]), isFalse);
      expect(icons.iconFor(_busStop.name), same(first));
    });

    test('não gera duas vezes em chamadas concorrentes', () async {
      final icons = NearbyStopMarkerIcons();

      final first = icons.ensure([_busStop.name]);
      final second = icons.ensure([_busStop.name]);

      expect(await first, isTrue);
      expect(await second, isFalse);
      expect(icons.iconFor(_busStop.name), isNotNull);
    });

    test('não gera ícones quando não há nomes', () async {
      final icons = NearbyStopMarkerIcons();

      expect(await icons.ensure(const []), isFalse);
      expect(icons.iconFor(_busStop.name), isNull);
    });
  });
}
