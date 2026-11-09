import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../../../domain/models/tracked_line.dart';
import '../../../../../core/extensions/line_map_color.dart';
import 'map_tracking_polylines.dart';

/// Cria os marcadores dos ônibus encontrados pelo rastreamento.
///
/// Cada ônibus aparece com um marcador na mesma cor da linha acompanhada.
/// [iconFor] devolve o ícone já gerado para a cor; enquanto ele ainda não
/// existe, o marcador usa o ícone padrão do Google Maps colorido pela matiz da
/// linha.
Set<Marker> buildTrackingBusMarkers(
  List<TrackedLine> trackedLines, {
  BitmapDescriptor? Function(Color color)? iconFor,
}) {
  return {
    for (final tracked in trackedLines)
      for (final position in tracked.busPositions)
        Marker(
          markerId: MarkerId(
            'bus-${trackedLineKey(tracked)}-${position.bus.code}',
          ),
          position: LatLng(position.latitude, position.longitude),
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 1,
          icon:
              iconFor?.call(tracked.line.mapColor) ??
              _fallbackIcon(tracked.line.mapColor),
          infoWindow: InfoWindow(
            title:
                'Linha ${trackedLineKey(tracked)} • '
                'Ônibus ${position.bus.code}',
            snippet: 'Atualizado às ${_formatCapturedAt(position.capturedAt)}',
          ),
        ),
  };
}

/// Matiz usada no ícone provisório enquanto a cor exata não foi gerada.
double busMarkerFallbackHue(Color color) => HSLColor.fromColor(color).hue;

BitmapDescriptor _fallbackIcon(Color color) =>
    BitmapDescriptor.defaultMarkerWithHue(busMarkerFallbackHue(color));

String _formatCapturedAt(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Gera e mantém em cache os ícones dos marcadores de ônibus.
///
/// O ícone padrão do Google Maps só aceita uma matiz aproximada, então cada
/// cor de linha é desenhada uma única vez em um selo circular e convertida em
/// PNG para o mapa.
class TrackingBusMarkerIcons {
  static const double _size = 96;
  static const double _displaySize = 30;

  final Map<int, BitmapDescriptor> _icons = <int, BitmapDescriptor>{};
  final Map<int, Future<void>> _pending = <int, Future<void>>{};

  /// Ícone já pronto para [color], ou `null` enquanto não foi gerado.
  BitmapDescriptor? operator [](Color color) => _icons[color.toARGB32()];

  /// Gera os ícones das [colors] que ainda não existem.
  ///
  /// Cores repetidas são ignoradas e chamadas concorrentes não geram o mesmo
  /// ícone duas vezes. Retorna `true` quando iniciou a geração de pelo menos
  /// uma cor nova.
  Future<bool> ensure(Iterable<Color> colors) async {
    final pending = <Future<void>>[];
    var created = false;

    for (final color in colors) {
      final key = color.toARGB32();
      if (_icons.containsKey(key) || _pending.containsKey(key)) {
        continue;
      }

      created = true;
      final future = _buildIcon(color).then<void>((icon) {
        _pending.remove(key);
        if (icon != null) {
          _icons[key] = icon;
        }
      });
      _pending[key] = future;
      pending.add(future);
    }

    if (pending.isNotEmpty) {
      await Future.wait(pending);
    }
    return created;
  }

  Future<BitmapDescriptor?> _buildIcon(Color color) async {
    final recorder = ui.PictureRecorder();
    try {
      _paintIcon(Canvas(recorder), color);

      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(_size.toInt(), _size.toInt());
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          if (data == null) {
            return null;
          }
          return BitmapDescriptor.bytes(
            data.buffer.asUint8List(),
            width: _displaySize,
            height: _displaySize,
          );
        } finally {
          image.dispose();
        }
      } finally {
        picture.dispose();
      }
    } catch (_) {
      // Sem o ícone exato, o marcador continua com o fallback por matiz.
      return null;
    }
  }

  /// Desenha um selo circular na cor da linha com um ônibus branco no centro.
  void _paintIcon(Canvas canvas, Color color) {
    const center = Offset(_size / 2, _size / 2);
    final white = Paint()..color = Colors.white;
    final fill = Paint()..color = color;

    canvas.drawCircle(center, _size / 2, white);
    canvas.drawCircle(center, _size / 2 - 4, fill);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(26, 30, 44, 34),
        const Radius.circular(8),
      ),
      white,
    );

    for (final left in const [32.0, 50.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, 36, 14, 12),
          const Radius.circular(3),
        ),
        fill,
      );
    }

    canvas.drawCircle(const Offset(36, 66), 5, white);
    canvas.drawCircle(const Offset(60, 66), 5, white);
  }
}
