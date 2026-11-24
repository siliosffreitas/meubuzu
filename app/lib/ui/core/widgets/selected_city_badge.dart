import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Variantes visuais do [SelectedCityBadge].
enum SelectedCityBadgeVariant {
  /// Texto forte, exibido sobre o mapa acima da barra de busca.
  onMap,

  /// Texto secundário, exibido no rodapé da tela de busca.
  footer,
}

/// Indicador da cidade selecionada, usado no mapa e na tela de busca.
///
/// Exibe apenas o texto (sem ícone) para manter fidelidade ao layout. Quando
/// [label] está vazio o widget não ocupa espaço, evitando um rótulo quebrado
/// antes de a cidade ser escolhida.
class SelectedCityBadge extends StatelessWidget {
  const SelectedCityBadge({
    super.key,
    required this.label,
    this.variant = SelectedCityBadgeVariant.onMap,
  });

  /// Nome amigável da cidade, já no formato `"Nome, UF"`.
  final String label;

  final SelectedCityBadgeVariant variant;

  @override
  Widget build(BuildContext context) {
    final text = label.trim();
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    final isFooter = variant == SelectedCityBadgeVariant.footer;
    return Container(
      width: double.infinity,
      padding: isFooter
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
          : EdgeInsets.zero,
      decoration: isFooter
          ? const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.border, width: 1),
              ),
            )
          : null,
      child: Text(
        text,
        style: isFooter
            ? const TextStyle(fontSize: 13.5, color: AppColors.textSecondary)
            : const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
      ),
    );
  }
}
