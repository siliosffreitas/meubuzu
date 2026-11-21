import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../../../domain/models/tracked_line.dart';
import '../../../../../core/extensions/line_map_color.dart';
import 'map_tracking_directions.dart';
import 'map_tracking_polylines.dart';

/// Cria os marcadores dos ônibus encontrados pelo rastreamento.
///
/// Cada ônibus aparece com um marcador na mesma cor da linha acompanhada.
/// [iconFor] devolve o ícone já gerado para a cor; enquanto ele ainda não
/// existe, o marcador usa o ícone padrão do Google Maps colorido pela matiz da
/// linha.
///
/// [bearings] traz o rumo calculado pelo backend para cada ônibus, por
/// [trackedBusKey]. Quando ele é conhecido, um segundo marcador em forma de
/// seta é criado sobre o ônibus, girando em volta dele para indicar o sentido
/// do movimento.
///
/// [positions] permite exibir uma posição interpolada pela animação; sem ela,
/// o marcador usa a posição exata da captura.
Set<Marker> buildTrackingBusMarkers(
  List<TrackedLine> trackedLines, {
  Map<String, LatLng> positions = const {},
  Map<String, double> bearings = const {},
  BitmapDescriptor? Function(Color color)? iconFor,
  BitmapDescriptor? Function(Color color)? arrowIconFor,
}) {
  final markers = <Marker>{};

  for (final tracked in trackedLines) {
    final lineKey = trackedLineKey(tracked);
    final color = tracked.line.mapColor;

    for (final position in tracked.busPositions) {
      final key = trackedBusKey(tracked, position);
      final target =
          positions[key] ?? LatLng(position.latitude, position.longitude);

      markers.add(
        Marker(
          markerId: MarkerId('bus-$lineKey-${position.bus.code}'),
          position: target,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 1,
          icon: iconFor?.call(color) ?? _fallbackIcon(color),
          infoWindow: InfoWindow(
            title: 'Linha $lineKey • Ônibus ${position.bus.code}',
            snippet: 'Atualizado às ${_formatCapturedAt(position.capturedAt)}',
          ),
        ),
      );

      final bearing = bearings[key];
      if (bearing == null) {
        continue;
      }

      final arrowIcon = arrowIconFor?.call(color);
      if (arrowIcon == null) {
        continue;
      }

      // A âncora fica no centro do ônibus, então a seta orbita o selo e
      // continua apontando para fora, na direção do movimento, em qualquer
      // nível de zoom.
      markers.add(
        Marker(
          markerId: MarkerId('bus-arrow-$lineKey-${position.bus.code}'),
          position: target,
          anchor: const Offset(0.5, 1),
          rotation: bearing,
          zIndexInt: 2,
          icon: arrowIcon,
          infoWindow: InfoWindow.noText,
        ),
      );
    }
  }

  return markers;
}

/// Matiz usada no ícone provisório enquanto a cor exata não foi gerada.
double busMarkerFallbackHue(Color color) => HSLColor.fromColor(color).hue;

BitmapDescriptor _fallbackIcon(Color color) =>
    BitmapDescriptor.defaultMarkerWithHue(busMarkerFallbackHue(color));

/// Converte DateTime de UTC para o fuso local antes de formatar.
/// O backend salva capturedAt em UTC; sem isso o app exibe horario +3h para cidades como Sao Paulo (UTC-3).
String _formatCapturedAt(DateTime value) {
  value = value.toLocal();
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Gera e mantém em cache os ícones dos marcadores de ônibus.
///
/// O ícone padrão do Google Maps só aceita uma matiz aproximada, então cada
/// cor de linha é desenhada uma única vez em um selo circular e em uma seta de
/// direção, convertidos em PNG para o mapa.
class TrackingBusMarkerIcons {
  static const double _size = 96;
  static const double _displaySize = 30;

  static const double _arrowWidth = 64;
  static const double _arrowHeight = 80;
  static const double _arrowDisplayWidth = 32;
  static const double _arrowDisplayHeight = 40;

  /// Largura do selo de referência (`bus_mark.png`), usada como base para as
  /// medidas do glifo do ônibus.
  static const double _busDesignSize = 62;

  final Map<int, BitmapDescriptor> _icons = <int, BitmapDescriptor>{};
  final Map<int, BitmapDescriptor> _arrowIcons = <int, BitmapDescriptor>{};
  final Map<int, Future<void>> _pending = <int, Future<void>>{};

  /// Ícone já pronto do ônibus para [color], ou `null` enquanto não foi gerado.
  BitmapDescriptor? operator [](Color color) => _icons[color.toARGB32()];

  /// Ícone já pronto da seta de direção, ou `null` enquanto não foi gerado.
  BitmapDescriptor? arrow(Color color) => _arrowIcons[color.toARGB32()];

  /// Gera os ícones das [colors] que ainda não existem.
  ///
  /// Cores repetidas são ignoradas e chamadas concorrentes não geram os mesmos
  /// ícones duas vezes. Retorna `true` quando iniciou a geração de pelo menos
  /// uma cor nova.
  Future<bool> ensure(Iterable<Color> colors) async {
    final pending = <Future<void>>[];
    var created = false;

    for (final color in colors) {
      final key = color.toARGB32();
      if ((_icons.containsKey(key) && _arrowIcons.containsKey(key)) ||
          _pending.containsKey(key)) {
        continue;
      }

      created = true;
      final future = _buildIcons(color).whenComplete(() {
        _pending.remove(key);
      });
      _pending[key] = future;
      pending.add(future);
    }

    if (pending.isNotEmpty) {
      await Future.wait(pending);
    }
    return created;
  }

  Future<void> _buildIcons(Color color) async {
    final key = color.toARGB32();

    if (!_icons.containsKey(key)) {
      final icon = await _buildIcon(
        color,
        _paintBusIcon,
        canvasWidth: _size,
        canvasHeight: _size,
        displayWidth: _displaySize,
        displayHeight: _displaySize,
      );
      if (icon != null) {
        _icons[key] = icon;
      }
    }

    if (!_arrowIcons.containsKey(key)) {
      final arrow = await _buildIcon(
        color,
        _paintArrowIcon,
        canvasWidth: _arrowWidth,
        canvasHeight: _arrowHeight,
        displayWidth: _arrowDisplayWidth,
        displayHeight: _arrowDisplayHeight,
      );
      if (arrow != null) {
        _arrowIcons[key] = arrow;
      }
    }
  }

  Future<BitmapDescriptor?> _buildIcon(
    Color color,
    void Function(Canvas canvas, Color color) paint, {
    required double canvasWidth,
    required double canvasHeight,
    required double displayWidth,
    required double displayHeight,
  }) async {
    final recorder = ui.PictureRecorder();
    try {
      paint(Canvas(recorder), color);

      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(
          canvasWidth.toInt(),
          canvasHeight.toInt(),
        );
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          if (data == null) {
            return null;
          }
          return BitmapDescriptor.bytes(
            data.buffer.asUint8List(),
            width: displayWidth,
            height: displayHeight,
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
  ///
  /// O desenho segue o `bus_mark.png`: o círculo é preenchido inteiramente com
  /// a cor da linha (sem anel branco) e o ônibus é branco, com letreiro,
  /// para-brisa, faróis e vão inferior vazados mostrando a cor do selo.
  void _paintBusIcon(Canvas canvas, Color color) {
    const center = Offset(_size / 2, _size / 2);
    final white = Paint()..color = Colors.white;
    final fill = Paint()..color = color;

    canvas.drawCircle(center, _size / 2, fill);

    // As medidas do glifo foram tiradas de um selo de 62 px.
    canvas.save();
    canvas.scale(_size / _busDesignSize);

    // Corpo do ônibus.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(15, 12, 31, 39),
        const Radius.circular(4),
      ),
      white,
    );

    // Letreiro, com um brilho claro na borda de cima como na referência.
    final signTop = Paint()..color = Color.lerp(color, Colors.white, 0.5)!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(26, 14, 10, 1.5),
        const Radius.circular(0.8),
      ),
      signTop,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(26, 15.5, 10, 1.5),
        const Radius.circular(0.8),
      ),
      fill,
    );

    // Para-brisa vazado.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(17, 19.5, 27, 16),
        const Radius.circular(2),
      ),
      fill,
    );

    // Retrovisores laterais.
    for (final left in const [9.5, 50.5]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, 22, 2, 8.5),
          const Radius.circular(1),
        ),
        white,
      );
    }

    // Faróis vazados.
    for (final left in const [17.5, 39.5]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, 38.5, 4.5, 4.5),
          const Radius.circular(1.2),
        ),
        fill,
      );
    }

    // Vão inferior central.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(25.5, 46, 10, 4.5),
        const Radius.circular(1.2),
      ),
      fill,
    );

    canvas.restore();
  }

  /// Desenha a seta na parte de cima do ícone, apontando para cima.
  ///
  /// A âncora do marcador fica na base do canvas, então a seta aparece logo
  /// acima do selo do ônibus e gira em volta dele. Segue o `arrow.png`: um
  /// triângulo preenchido na cor da linha, com um entalhe em "V" na base.
  void _paintArrowIcon(Canvas canvas, Color color) {
    canvas.drawPath(
      Path()
        ..moveTo(_arrowWidth / 2, 26)
        ..lineTo(18, 47)
        ..lineTo(_arrowWidth / 2, 41.5)
        ..lineTo(46, 47)
        ..close(),
      Paint()..color = color,
    );
  }
}
