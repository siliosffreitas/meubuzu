import 'package:flutter/material.dart';

import '../../../../core/extensions/line_direction_label.dart';
import '../../../../core/extensions/line_map_color.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../../domain/models/line.dart';

/// Cabeçalho com o código, o nome e o sentido da linha.
class LineDetailsHeader extends StatelessWidget {
  const LineDetailsHeader({
    super.key,
    required this.line,
    this.isTracking = false,
  });

  final Line line;

  /// Indica se a linha já está sendo acompanhada no mapa.
  final bool isTracking;

  String get _displayCode => line.publicCode;

  @override
  Widget build(BuildContext context) {
    final direction = line.directionLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: lineMapColor(_displayCode, line.name),
                borderRadius: BorderRadius.circular(16),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _displayCode,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.name,
                    style: const TextStyle(
                      fontSize: 21,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (direction.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      direction,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _TrackingStatusPill(isTracking: isTracking),
      ],
    );
  }
}

class _TrackingStatusPill extends StatelessWidget {
  const _TrackingStatusPill({required this.isTracking});

  final bool isTracking;

  @override
  Widget build(BuildContext context) {
    const color = AppColors.primaryPressed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isTracking ? AppColors.primarySurface : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isTracking
                ? Icons.location_on_rounded
                : Icons.directions_bus_filled_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            isTracking ? 'Acompanhando no mapa' : 'Não acompanhada',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
