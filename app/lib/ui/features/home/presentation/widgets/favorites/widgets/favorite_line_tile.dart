import 'package:flutter/material.dart';

import '../../../../../../core/extensions/line_map_color.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/widgets/favorite_star_button.dart';
import '../../../../../../../domain/models/favorite.dart';

/// Item da aba Favoritos: toque abre os detalhes, estrela remove o favorito.
class FavoriteLineTile extends StatelessWidget {
  const FavoriteLineTile({
    super.key,
    required this.favorite,
    required this.onOpen,
    required this.onRemove,
  });

  final Favorite favorite;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final route = favorite.routeDescription;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 52),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            decoration: BoxDecoration(
              color: lineMapColor(favorite.displayCode, favorite.line.name),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              favorite.displayCode,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      favorite.line.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (route.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        route,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          FavoriteStarButton(isFavorite: true, onTap: onRemove),
        ],
      ),
    );
  }
}
