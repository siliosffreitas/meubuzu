import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Estrela que alterna o favorito de uma linha sem disparar o toque no item.
class FavoriteStarButton extends StatelessWidget {
  const FavoriteStarButton({
    super.key,
    required this.isFavorite,
    this.onTap,
    this.tooltip,
  });

  final bool isFavorite;

  /// Quando nulo, o botão aparece desabilitado.
  final VoidCallback? onTap;

  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip:
          tooltip ??
          (isFavorite ? 'Remover dos favoritos' : 'Adicionar aos favoritos'),
      onPressed: onTap,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      icon: Icon(
        isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
        size: 22,
        color: isFavorite ? AppColors.primary : AppColors.textSecondary,
      ),
    );
  }
}
