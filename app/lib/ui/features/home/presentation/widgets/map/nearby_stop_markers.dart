import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../../../domain/models/bus_stop.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/stop_ring_icon.dart';

/// Diâmetro do anel da parada, em unidades de exibição.
const nearbyStopMarkerDiameter = stopRingDiameter;

/// Espessura da borda do anel, em unidades de exibição.
const nearbyStopMarkerStrokeWidth = stopRingStrokeWidth;

/// Tamanho do nome da parada exibido no marcador.
const nearbyStopLabelTextSize = 10.5;

/// Espessura do contorno do nome da parada no marcador.
const nearbyStopLabelStrokeWidth = 1.4;

/// Estilo do preenchimento do nome da parada exibido no canto superior direito
/// do marcador.
///
/// As letras usam a cor principal do app.
TextStyle buildNearbyStopLabelFillStyle() {
  return const TextStyle(
    fontSize: nearbyStopLabelTextSize,
    height: 1.1,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );
}

/// Estilo da borda do nome da parada exibido no marcador.
///
/// A borda é branca e desenhada apenas com contorno (`PaintingStyle.stroke`),
/// por baixo do preenchimento, para destacar o nome sobre o mapa.
TextStyle buildNearbyStopLabelStrokeStyle() {
  return TextStyle(
    fontSize: nearbyStopLabelTextSize,
    height: 1.1,
    fontWeight: FontWeight.w600,
    foreground: Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = nearbyStopLabelStrokeWidth
      ..color = Colors.white,
  );
}

/// Margem entre o desenho e as bordas do ícone do marcador.
const double _iconMargin = 2;

/// Espaço entre o anel e o nome da parada.
const double _labelGap = 3;

/// Largura máxima do nome da parada antes de ser truncado.
const double _maxLabelWidth = 110;

/// Desenha um anel na cor do app com o centro transparente.
void paintNearbyStopMarker(
  Canvas canvas, {
  Offset? center,
  double diameter = nearbyStopMarkerDiameter,
  double strokeWidth = nearbyStopMarkerStrokeWidth,
}) {
  final ringCenter = center ?? Offset(diameter / 2, diameter / 2);

  paintStopRing(
    canvas,
    center: ringCenter,
    diameter: diameter,
    strokeWidth: strokeWidth,
  );
}

/// Desenha o marcador da parada: o anel com o nome no canto superior direito.
///
/// O nome é pintado sem fundo, direto sobre o mapa: letras verdes na cor
/// principal do app com borda branca, e o anel fica abaixo e à esquerda dele.
/// Retorna o tamanho lógico do desenho e o centro do anel, para posicionar a
/// âncora do marcador.
({Size size, Offset ringCenter}) paintNearbyStopMarkerIcon(
  Canvas canvas,
  String name,
) {
  final label = _labelPainter(name, buildNearbyStopLabelFillStyle());
  final border = _labelPainter(name, buildNearbyStopLabelStrokeStyle());

  final ringCenterX = _iconMargin + nearbyStopMarkerDiameter / 2;
  final labelLeft = ringCenterX + nearbyStopMarkerDiameter / 2 + _labelGap;
  final ringTop = label.height + _labelGap;
  final ringCenterY = ringTop + nearbyStopMarkerDiameter / 2;

  // A borda branca fica por baixo do preenchimento verde do nome.
  border.paint(canvas, Offset(labelLeft, 0));
  label.paint(canvas, Offset(labelLeft, 0));
  paintNearbyStopMarker(canvas, center: Offset(ringCenterX, ringCenterY));

  final width = labelLeft + label.width + _iconMargin;
  final height = ringTop + nearbyStopMarkerDiameter + _iconMargin;
  return (
    size: Size(width, height),
    ringCenter: Offset(ringCenterX, ringCenterY),
  );
}

/// Mede o texto do nome da parada com o [style] informado.
TextPainter _labelPainter(String name, TextStyle style) {
  return TextPainter(
    text: TextSpan(text: name, style: style),
    maxLines: 1,
    ellipsis: '…',
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: _maxLabelWidth);
}

/// Cria os marcadores das paradas próximas exibidas no mapa.
///
/// [iconFor] e [anchorFor] recebem o ícone e a âncora de cada parada, que
/// incluem o nome ao lado do anel. Sem eles, o marcador usa o pino verde padrão
/// do Google Maps até o ícone ficar pronto.
///
/// [onTap] é chamado quando o usuário toca no marcador da parada.
Set<Marker> buildNearbyStopMarkers(
  Iterable<BusStop> stops, {
  BitmapDescriptor? Function(BusStop stop)? iconFor,
  Offset? Function(BusStop stop)? anchorFor,
  void Function(BusStop stop)? onTap,
}) {
  return {
    for (final stop in stops)
      Marker(
        markerId: MarkerId('stop-${stop.id}'),
        position: LatLng(stop.latitude, stop.longitude),
        anchor: anchorFor?.call(stop) ?? const Offset(0.5, 1.0),
        infoWindow: InfoWindow(title: stop.name, snippet: stop.address),
        icon:
            iconFor?.call(stop) ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        onTap: onTap == null ? null : () => onTap(stop),
      ),
  };
}

/// Gera e mantém em cache o ícone de cada parada próxima.
///
/// O ícone traz o anel na cor do app e o nome da parada no canto superior
/// direito, com letras verdes e borda branca, sem fundo atrás do nome. Cada
/// nome é desenhado uma única vez e reutilizado por todas as paradas com o
/// mesmo nome.
class NearbyStopMarkerIcons {
  static const double _scale = 4;

  final Map<String, BitmapDescriptor> _icons = <String, BitmapDescriptor>{};
  final Map<String, Offset> _anchors = <String, Offset>{};
  final Map<String, Future<void>> _pending = <String, Future<void>>{};

  /// Ícone já pronto da parada com [name], ou `null` enquanto não foi gerado.
  BitmapDescriptor? iconFor(String name) => _icons[name];

  /// Âncora do anel dentro do ícone de [name], ou `null` antes de gerar.
  Offset? anchorFor(String name) => _anchors[name];

  /// Gera os ícones dos [names] que ainda não existem.
  ///
  /// Retorna `true` quando iniciou a geração de pelo menos um nome novo.
  Future<bool> ensure(Iterable<String> names) async {
    final pending = <Future<void>>[];
    var created = false;

    for (final name in names) {
      if (_icons.containsKey(name) || _pending.containsKey(name)) {
        continue;
      }

      created = true;
      final future = _build(name).whenComplete(() {
        _pending.remove(name);
      });
      _pending[name] = future;
      pending.add(future);
    }

    if (pending.isNotEmpty) {
      await Future.wait(pending);
    }
    return created;
  }

  Future<void> _build(String name) async {
    final recorder = ui.PictureRecorder();
    try {
      final canvas = Canvas(recorder)..scale(_scale);
      final icon = paintNearbyStopMarkerIcon(canvas, name);
      final anchor = Offset(
        icon.ringCenter.dx / icon.size.width,
        icon.ringCenter.dy / icon.size.height,
      );

      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(
          (icon.size.width * _scale).ceil(),
          (icon.size.height * _scale).ceil(),
        );
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          if (data == null) {
            return;
          }
          _icons[name] = BitmapDescriptor.bytes(
            data.buffer.asUint8List(),
            width: icon.size.width,
            height: icon.size.height,
          );
          _anchors[name] = anchor;
        } finally {
          image.dispose();
        }
      } finally {
        picture.dispose();
      }
    } catch (_) {
      // Sem o ícone exato, o mapa mantém o pino verde padrão.
    }
  }
}
