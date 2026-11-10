import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../../domain/models/bus_stop.dart';

/// Cabeçalho com o código, o nome, o endereço e a distância até a parada.
class BusStopDetailsHeader extends StatelessWidget {
  const BusStopDetailsHeader({
    super.key,
    required this.busStop,
    this.distanceInMeters,
  });

  final BusStop busStop;

  /// Distância do usuário até a parada. Quando nula, a linha é omitida.
  final double? distanceInMeters;

  @override
  Widget build(BuildContext context) {
    final code = busStop.code.trim();
    final address = busStop.address.trim();
    final distance = distanceInMeters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            code.isEmpty ? 'PARADA' : 'PARADA · $code',
            style: const TextStyle(
              fontSize: 12,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: AppColors.primaryPressed,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          busStop.name,
          style: const TextStyle(
            fontSize: 30,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: AppColors.textPrimary,
          ),
        ),
        if (address.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            address,
            style: const TextStyle(
              fontSize: 15.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (distance != null) ...[
          const SizedBox(height: 10),
          Text(
            formatDistanceInMeters(distance),
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryPressed,
            ),
          ),
        ],
      ],
    );
  }
}

/// Formata a distância até a parada em metros ou quilômetros.
String formatDistanceInMeters(double distanceInMeters) {
  if (distanceInMeters < 1000) {
    return 'A ${distanceInMeters.round()} m de você';
  }
  final kilometers = (distanceInMeters / 1000).toStringAsFixed(1);
  return 'A ${kilometers.replaceAll('.', ',')} km de você';
}
