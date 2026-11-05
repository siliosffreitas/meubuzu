import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_colors.dart';

/// Campo de busca flutuante exibido sobre o mapa.
///
/// Funciona como acionador da tela dedicada de busca: tocar nele abre a tela
/// de busca e, ao voltar, exibe a sugestão selecionada.
class MapSearchBar extends StatelessWidget {
  const MapSearchBar({
    super.key,
    required this.onTap,
    this.text,
    this.hintText = 'Buscar linha ou parada',
  });

  final VoidCallback onTap;

  /// Texto da sugestão selecionada. Quando vazio, mostra o [hintText].
  final String? text;
  final String hintText;

  bool get _hasText => text != null && text!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 10,
      shadowColor: const Color(0x1F2E3C3E),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              const SizedBox(width: 16),
              const Icon(
                Icons.search_rounded,
                size: 22,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _hasText ? text!.trim() : hintText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: _hasText ? FontWeight.w600 : FontWeight.w400,
                    color: _hasText
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}
