import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Barra superior das telas de detalhes, com o botão de voltar e o título.
class DetailsTopBar extends StatelessWidget {
  const DetailsTopBar({
    super.key,
    required this.title,
    required this.onBack,
    this.action,
  });

  final String title;
  final VoidCallback onBack;

  /// Ação opcional exibida no fim da barra, como a estrela de favorito.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 24, 8),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            label: const Text('Voltar'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryPressed,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (action != null) ...[const SizedBox(width: 4), action!],
        ],
      ),
    );
  }
}
