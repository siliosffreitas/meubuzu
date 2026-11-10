import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Diâmetro padrão do anel que identifica uma parada, em unidades de exibição.
const stopRingDiameter = 14.0;

/// Espessura padrão da borda do anel de parada.
const stopRingStrokeWidth = 2.8;

/// Desenha um anel na cor informada, com o centro transparente.
///
/// É a mesma pintura usada no marcador da parada no mapa e no ícone do
/// itinerário na tela de detalhes.
void paintStopRing(
  Canvas canvas, {
  required Offset center,
  required double diameter,
  required double strokeWidth,
  Color color = AppColors.primary,
}) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth;

  canvas.drawCircle(center, (diameter - strokeWidth) / 2, paint);
}

/// Ícone circular de parada: um anel na cor do app, sem preenchimento.
class StopRingIcon extends StatelessWidget {
  const StopRingIcon({
    super.key,
    this.size = stopRingDiameter,
    this.strokeWidth = stopRingStrokeWidth,
    this.color = AppColors.primary,
  });

  /// Diâmetro externo do anel.
  final double size;

  /// Espessura da borda do anel.
  final double strokeWidth;

  /// Cor da borda.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _StopRingPainter(
          diameter: size,
          strokeWidth: strokeWidth,
          color: color,
        ),
      ),
    );
  }
}

class _StopRingPainter extends CustomPainter {
  const _StopRingPainter({
    required this.diameter,
    required this.strokeWidth,
    required this.color,
  });

  final double diameter;
  final double strokeWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    paintStopRing(
      canvas,
      center: Offset(size.width / 2, size.height / 2),
      diameter: diameter,
      strokeWidth: strokeWidth,
      color: color,
    );
  }

  @override
  bool shouldRepaint(_StopRingPainter oldDelegate) {
    return oldDelegate.diameter != diameter ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.color != color;
  }
}
