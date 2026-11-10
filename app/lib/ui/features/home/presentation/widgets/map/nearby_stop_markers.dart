import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../../../domain/models/bus_stop.dart';
import '../../../../../core/theme/app_colors.dart';

/// Diâmetro do anel da parada, em unidades de exibição.
const nearbyStopMarkerDiameter = 14.0;

/// Espessura da borda do anel, em unidades de exibição.
const nearbyStopMarkerStrokeWidth = 2.8;

/// Desenha um anel na cor do app com o centro transparente.
void paintNearbyStopMarker(
  Canvas canvas, {
  Offset? center,
  double diameter = nearbyStopMarkerDiameter,
  double strokeWidth = nearbyStopMarkerStrokeWidth,
}) {
  final ringCenter = center ?? Offset(diameter / 2, diameter / 2);
  final paint = Paint()
    ..color = AppColors.primary
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth;

  canvas.drawCircle(ringCenter, (diameter - strokeWidth) / 2, paint);
}

/// Cria os marcadores das paradas próximas exibidas no mapa.
///
/// [iconFor] e [anchorFor] recebem o ícone e a âncora de cada parada, que
/// incluem o nome ao lado do anel. Sem eles, o marcador usa o pino verde padrão
/// do Google Maps até o ícone ficar pronto.
Set<Marker> buildNearbyStopMarkers(
  Iterable<BusStop> stops, {
  BitmapDescriptor? Function(BusStop stop)? iconFor,
  Offset? Function(BusStop stop)? anchorFor,
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
      ),
  };
}

/// Gera e mantém em cache o ícone de cada parada próxima.
///
/// O ícone traz o anel na cor do app e o nome da parada no canto superior
/// direito. Cada nome é desenhado uma única vez e reutilizado por todas as
/// paradas com o mesmo nome.
class NearbyStopMarkerIcons {
  static const double _scale = 4;
  static const double _ringMargin = 2;
  static const double _labelGap = 3;
  static const double _labelPaddingX = 5;
  static const double _labelPaddingY = 2.5;
  static const double _labelRadius = 4;
  static const double _textSize = 10.5;
  static const double _maxTextWidth = 110;

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
    final textPainter = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          fontSize: _textSize,
          height: 1.1,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _maxTextWidth);

    final labelWidth = textPainter.width + _labelPaddingX * 2;
    final labelHeight = textPainter.height + _labelPaddingY * 2;

    final ringCenterX = _ringMargin + nearbyStopMarkerDiameter / 2;
    final labelLeft = ringCenterX + nearbyStopMarkerDiameter / 2 + _labelGap;
    final ringTop = labelHeight + _labelGap;
    final ringCenterY = ringTop + nearbyStopMarkerDiameter / 2;

    final width = labelLeft + labelWidth + _ringMargin;
    final height = ringTop + nearbyStopMarkerDiameter + _ringMargin;
    final anchor = Offset(ringCenterX / width, ringCenterY / height);

    final recorder = ui.PictureRecorder();
    try {
      final canvas = Canvas(recorder)..scale(_scale);

      final labelRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(labelLeft, 0, labelWidth, labelHeight),
        const Radius.circular(_labelRadius),
      );
      canvas.drawRRect(
        labelRect,
        Paint()..color = Colors.white.withValues(alpha: 0.94),
      );
      textPainter.paint(
        canvas,
        Offset(labelLeft + _labelPaddingX, _labelPaddingY),
      );

      paintNearbyStopMarker(canvas, center: Offset(ringCenterX, ringCenterY));

      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(
          (width * _scale).ceil(),
          (height * _scale).ceil(),
        );
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          if (data == null) {
            return;
          }
          _icons[name] = BitmapDescriptor.bytes(
            data.buffer.asUint8List(),
            width: width,
            height: height,
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
