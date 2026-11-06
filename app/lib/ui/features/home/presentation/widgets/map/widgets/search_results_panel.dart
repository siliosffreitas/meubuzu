import 'package:flutter/material.dart';

import '../../../../../../core/extensions/line_map_color.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../../data/models/place_suggestion.dart';

/// Lista de resultados da busca de linhas e paradas.
///
/// Segue o layout de referência: resumo no topo, seções em destaque e itens
/// com código colorido, nome, complemento e chevron.
class SearchResultsPanel extends StatelessWidget {
  const SearchResultsPanel({
    super.key,
    required this.query,
    required this.isLoading,
    required this.results,
    required this.onSelected,
    this.maxHeight = 352,
    this.activeSuggestionId,
    this.statusLabel,
  });

  final String query;
  final bool isLoading;
  final List<PlaceSuggestion> results;
  final ValueChanged<PlaceSuggestion> onSelected;

  /// Altura máxima do painel. Use `double.infinity` para ocupar todo o espaço
  /// disponível na tela dedicada de busca.
  final double maxHeight;

  /// Linha atualmente exibida no mapa. Recebe o selo "Acompanhando no mapa".
  final String? activeSuggestionId;

  /// Texto opcional exibido no selo do cabeçalho, como a cota diária de
  /// rastreamentos.
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Buscando linhas e paradas…',
                style: TextStyle(
                  fontSize: 14.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 26,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Nenhum resultado',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Não encontramos linhas ou paradas para “$query”.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final lines = results
        .where((suggestion) => suggestion.type == PlaceSuggestionType.line)
        .toList(growable: false);
    final stops = results
        .where((suggestion) => suggestion.type == PlaceSuggestionType.stop)
        .toList(growable: false);

    final items = <Widget>[
      _ResultsSummary(count: results.length, statusLabel: statusLabel),
      if (lines.isNotEmpty) ...[
        _SectionHeader(title: 'Linhas', count: lines.length),
        ...lines.map(
          (suggestion) => _LineSuggestionTile(
            suggestion: suggestion,
            isActive: suggestion.id == activeSuggestionId,
            onTap: () => onSelected(suggestion),
          ),
        ),
      ],
      if (stops.isNotEmpty) ...[
        _SectionHeader(title: 'Paradas', count: stops.length),
        ...stops.map(
          (suggestion) => _StopSuggestionTile(
            suggestion: suggestion,
            onTap: () => onSelected(suggestion),
          ),
        ),
      ],
    ];

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 12),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }
}

/// Cabeçalho com a quantidade de resultados e, quando disponível, a cota
/// diária de rastreamentos.
class _ResultsSummary extends StatelessWidget {
  const _ResultsSummary({required this.count, this.statusLabel});

  final int count;
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$count ${count == 1 ? 'resultado' : 'resultados'}',
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (statusLabel != null) _StatusPill(label: statusLabel!),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.attentionSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 18, 8, 6),
      child: Text(
        '${title.toUpperCase()} • $count',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: AppColors.primaryPressed,
        ),
      ),
    );
  }
}

/// Item de linha: código em destaque, nome, trajeto e chevron.
class _LineSuggestionTile extends StatelessWidget {
  const _LineSuggestionTile({
    required this.suggestion,
    required this.isActive,
    required this.onTap,
  });

  final PlaceSuggestion suggestion;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 13, 4, 13),
        child: Row(
          children: [
            _LineCodeBadge(code: suggestion.code, name: suggestion.title),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (suggestion.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      suggestion.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (isActive) ...[
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
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Item de parada: ícone, nome, código e endereço.
class _StopSuggestionTile extends StatelessWidget {
  const _StopSuggestionTile({required this.suggestion, required this.onTap});

  final PlaceSuggestion suggestion;
  final VoidCallback onTap;

  String get _description {
    final code = suggestion.code.trim();
    final subtitle = suggestion.subtitle.trim();
    if (code.isEmpty) {
      return subtitle;
    }
    if (subtitle.startsWith('$code ')) {
      return subtitle;
    }
    return subtitle.isEmpty ? code : '$code • $subtitle';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 4, 12),
        child: Row(
          children: [
            const SizedBox(
              width: 24,
              child: Icon(
                Icons.location_on_rounded,
                size: 22,
                color: AppColors.primaryPressed,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Código da linha em bloco, como no layout de referência.
class _LineCodeBadge extends StatelessWidget {
  const _LineCodeBadge({required this.code, required this.name});

  final String code;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 52),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: lineMapColor(code, name),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        code,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: Colors.white,
        ),
      ),
    );
  }
}
