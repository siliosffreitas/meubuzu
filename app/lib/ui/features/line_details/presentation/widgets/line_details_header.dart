import 'package:flutter/material.dart';

import '../../../../core/extensions/line_map_color.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../../domain/models/line.dart';

/// Cabeçalho com o código, o nome e o trajeto da linha.
class LineDetailsHeader extends StatelessWidget {
  const LineDetailsHeader({super.key, required this.line});

  final Line line;

  String get _displayCode {
    final code = line.boardingCode?.trim();
    return code == null || code.isEmpty ? line.id : code;
  }

  String get _route {
    final origin = line.origin.trim();
    final destination = line.destination.trim();
    if (origin.isEmpty) {
      return destination;
    }
    if (destination.isEmpty) {
      return origin;
    }
    if (origin == destination) {
      return 'Circular • $origin';
    }
    return '$origin → $destination';
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 64),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: lineMapColor(_displayCode, line.name),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _displayCode,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (route.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    route,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
