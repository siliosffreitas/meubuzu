import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../../domain/models/bus_stop.dart';

/// Item do itinerário, com o marcador da parada e o código ao lado do nome.
class LineStopTimelineTile extends StatelessWidget {
  const LineStopTimelineTile({
    super.key,
    required this.stop,
    required this.isFirst,
    required this.isLast,
  });

  final BusStop stop;

  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final code = stop.code.trim();
    final lineColor = AppColors.primary.withValues(alpha: 0.45);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst ? Colors.transparent : lineColor,
                  ),
                ),
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 1.8),
                  ),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : lineColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: stop.name,
                      style: const TextStyle(
                        fontSize: 15.5,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (code.isNotEmpty)
                      TextSpan(
                        text: ' · $code',
                        style: const TextStyle(
                          fontSize: 15.5,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
