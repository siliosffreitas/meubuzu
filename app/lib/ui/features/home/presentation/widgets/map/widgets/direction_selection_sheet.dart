import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../../domain/models/line_direction.dart';
import '../../../../../../../domain/models/tracked_line.dart';

/// Modal de seleção do sentido/itinerário de uma linha acompanhada.
///
/// A lista pode estar vazia quando o catálogo ainda não possui itinerário para
/// a linha. Nesse caso o modal explica a indisponibilidade em vez de inventar
/// um sentido.
class DirectionSelectionSheet extends StatelessWidget {
  const DirectionSelectionSheet({super.key, required this.tracked});

  final TrackedLine tracked;

  String get _lineCode => tracked.line.publicCode;

  @override
  Widget build(BuildContext context) {
    final directions = tracked.directions;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Sentido da linha',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              directions.length > 1
                  ? 'Escolha qual itinerário será exibido no mapa.'
                  : directions.isEmpty
                  ? 'Esta linha ainda não possui itinerário cadastrado.'
                  : 'Itinerário disponível para esta linha.',
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            if (directions.isEmpty)
              const _EmptyDirections()
            else
              ...directions.map(
                (direction) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _DirectionOption(
                    lineCode: _lineCode,
                    direction: direction,
                    isSelected: direction.value == tracked.direction,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDirections extends StatelessWidget {
  const _EmptyDirections();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('direction-selection-empty'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.route_rounded, size: 26, color: AppColors.textSecondary),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Nenhum itinerário foi encontrado para esta linha. '
              'O rastreamento continua disponível.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionOption extends StatelessWidget {
  const _DirectionOption({
    required this.lineCode,
    required this.direction,
    required this.isSelected,
  });

  final String lineCode;
  final LineDirection direction;
  final bool isSelected;

  bool get _isEnabled => direction.hasRoute || isSelected;

  String get _label {
    final label = direction.label.trim();
    return label.isEmpty ? 'Sentido ${direction.value + 1}' : label;
  }

  String? get _details {
    final parts = <String>[
      if (direction.stopCount > 0)
        direction.stopCount == 1
            ? '1 parada'
            : '${direction.stopCount} paradas',
      if (!direction.hasRoute) 'Sem traçado',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;

    return Material(
      color: isSelected ? AppColors.primarySurface : AppColors.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('direction-option-$lineCode-${direction.value}'),
        onTap: _isEnabled
            ? () => Navigator.of(context).pop(direction.value)
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _label,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: _isEnabled
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                    if (details != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        details,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 23,
                color: isSelected
                    ? AppColors.primary
                    : _isEnabled
                    ? AppColors.surfaceMuted
                    : AppColors.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
