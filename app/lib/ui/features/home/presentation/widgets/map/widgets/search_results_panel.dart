import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../../data/models/place_suggestion.dart';

/// Cartão com os resultados da busca de linhas e paradas.
class SearchResultsPanel extends StatelessWidget {
  const SearchResultsPanel({
    super.key,
    required this.query,
    required this.isLoading,
    required this.results,
    required this.onSelected,
    this.maxHeight = 352,
  });

  final String query;
  final bool isLoading;
  final List<PlaceSuggestion> results;
  final ValueChanged<PlaceSuggestion> onSelected;

  /// Altura máxima do painel. Use `double.infinity` para ocupar todo o espaço
  /// disponível na tela dedicada de busca.
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 12,
      shadowColor: const Color(0x242E3C3E),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: _buildContent(context),
      ),
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
      if (lines.isNotEmpty) ...[
        _SectionHeader(title: 'Linhas', count: lines.length),
        ...lines.map(
          (suggestion) => _LineSuggestionTile(
            suggestion: suggestion,
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(
              height: 1,
              thickness: 0.6,
              indent: 72,
              endIndent: 16,
              color: AppColors.border,
            ),
            itemBuilder: (context, index) => items[index],
          ),
        ),
      ],
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
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            '$count ${count == 1 ? 'resultado' : 'resultados'}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Item de linha: código em destaque, nome e trajeto.
class _LineSuggestionTile extends StatelessWidget {
  const _LineSuggestionTile({required this.suggestion, required this.onTap});

  final PlaceSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            _LineCodeBadge(code: suggestion.code),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (suggestion.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      suggestion.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
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
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Item de parada: ícone, nome e endereço.
class _StopSuggestionTile extends StatelessWidget {
  const _StopSuggestionTile({required this.suggestion, required this.onTap});

  final PlaceSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.place_rounded,
                size: 21,
                color: AppColors.primary,
              ),
            ),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    suggestion.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Código da linha em bloco, como no layout de referência.
class _LineCodeBadge extends StatelessWidget {
  const _LineCodeBadge({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 50),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
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
