import 'package:flutter/material.dart';

import '../../../../core/extensions/line_map_color.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../../domain/models/line.dart';

/// Cabeçalho com o código, o nome e o sentido da linha.
class LineDetailsHeader extends StatelessWidget {
  const LineDetailsHeader({super.key, required this.line});

  final Line line;

  String get _displayCode {
    final code = line.boardingCode?.trim();
    return code == null || code.isEmpty ? line.id : code;
  }

  String get _direction {
    final origin = line.origin.trim();
    final destination = line.destination.trim();
    if (destination.isEmpty) {
      return origin;
    }
    if (origin.isNotEmpty && origin == destination) {
      return 'Circular • $origin';
    }
    return 'Sentido $destination';
  }

  @override
  Widget build(BuildContext context) {
    final direction = _direction;

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
        const _TrackingStatusPill(),
      ],
    );
  }
}

class _TrackingStatusPill extends StatelessWidget {
  const _TrackingStatusPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.directions_bus_filled_rounded,
            size: 18,
            color: AppColors.primaryPressed,
          ),
          SizedBox(width: 8),
          Text(
            'Não acompanhada',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryPressed,
            ),
          ),
        ],
      ),
    );
  }
}
