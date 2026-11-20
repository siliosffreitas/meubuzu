import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/line_map_color.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/favorite_star_button.dart';
import '../../../../../domain/models/line.dart';
import '../../../../routing/app_routes.dart';

/// Código usado para reconhecer a linha acompanhada (`sgLinha`).
String _trackingCode(Line line) => line.publicCode;

/// Card de uma linha que passa pela parada, com o código, o nome e o trajeto.
class BusStopLineTile extends StatelessWidget {
  const BusStopLineTile({
    super.key,
    required this.line,
    this.trackingLines = const {},
  });

  final Line line;

  /// Códigos (`sgLinha`) das linhas já acompanhadas no mapa.
  final Set<String> trackingLines;

  String get _displayCode => line.publicCode;

  String get _route {
    final origin = line.origin.trim();
    final destination = line.destination.trim();
    if (destination.isEmpty) {
      return origin;
    }
    if (origin.isNotEmpty && origin == destination) {
      return 'Circular • $origin';
    }
    if (origin.isEmpty) {
      return destination;
    }
    return '$origin → $destination';
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D2E3C3E),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: lineMapColor(_displayCode, line.name),
              borderRadius: BorderRadius.circular(12),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _displayCode,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.1,
                  color: Colors.white,
                ),
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
                    fontSize: 16.5,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (route.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    route,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (trackingLines.contains(_trackingCode(line))) ...[
                  const SizedBox(height: 5),
                  const Text(
                    'Acompanhando no mapa',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryPressed,
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

/// Widget que exibe o tile da linha com navegação para os detalhes da linha.
class BusStopLineTileWithNavigation extends StatelessWidget {
  const BusStopLineTileWithNavigation({
    super.key,
    required this.line,
    this.trackingLines = const {},
    this.isFavorite = false,
    this.onFavoriteTap,
  });

  final Line line;

  /// Códigos (`sgLinha`) das linhas já acompanhadas no mapa.
  final Set<String> trackingLines;

  /// Indica que a linha já está favorita.
  final bool isFavorite;

  /// Ação da estrela. Quando nula, a estrela não é exibida.
  final VoidCallback? onFavoriteTap;

  String get _displayCode => line.publicCode;

  String get _route {
    final origin = line.origin.trim();
    final destination = line.destination.trim();
    if (destination.isEmpty) {
      return origin;
    }
    if (origin.isNotEmpty && origin == destination) {
      return 'Circular • $origin';
    }
    if (origin.isEmpty) {
      return destination;
    }
    return '$origin → $destination';
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D2E3C3E),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => context.pushNamed<bool>(
                  AppRoutes.detailsLineName,
                  pathParameters: {'code': line.publicCode},
                ),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      decoration: BoxDecoration(
                        color: lineMapColor(_displayCode, line.name),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _displayCode,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 20,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.1,
                            color: Colors.white,
                          ),
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
                              fontSize: 16.5,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (route.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              route,
                              style: const TextStyle(
                                fontSize: 13.5,
                                height: 1.35,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          if (trackingLines.contains(_trackingCode(line))) ...[
                            const SizedBox(height: 5),
                            const Text(
                              'Acompanhando no mapa',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryPressed,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (onFavoriteTap != null)
              FavoriteStarButton(isFavorite: isFavorite, onTap: onFavoriteTap!),
          ],
        ),
      ),
    );
  }
}
