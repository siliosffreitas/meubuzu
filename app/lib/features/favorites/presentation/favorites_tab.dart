import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tab_header.dart';

/// Aba de linhas favoritas. O conteúdo será ligado ao backend futuramente.
class FavoritesTab extends StatelessWidget {
  const FavoritesTab({super.key, required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TabHeader(
                title: 'Favoritos',
                subtitle: 'Suas linhas sempre à mão.',
              ),
              Expanded(
                child: EmptyState(
                  icon: Icons.star_outline_rounded,
                  title: 'Nenhuma linha favorita',
                  message:
                      'Favorite uma linha para acessá-la rapidamente na aba '
                      'Mapa.',
                  action: OutlinedButton.icon(
                    onPressed: onExplore,
                    icon: const Icon(Icons.map_outlined, size: 19),
                    label: const Text('Ir para o mapa'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
