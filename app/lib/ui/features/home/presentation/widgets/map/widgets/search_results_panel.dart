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
    this.trackedLineCodes = const {},
    this.statusLabel,
    this.onEditSearch,
  });

  final String query;
  final bool isLoading;
  final List<PlaceSuggestion> results;
  final ValueChanged<PlaceSuggestion> onSelected;

  /// Ação do botão "Editar busca" exibido no estado vazio. Quando nulo, o
  /// botão não é renderizado.
  final VoidCallback? onEditSearch;

  /// Altura máxima do painel. Use `double.infinity` para ocupar todo o espaço
  /// disponível na tela dedicada de busca.
  final double maxHeight;

  /// Linha atualmente exibida no mapa. Recebe o selo "Acompanhando no mapa".
  final String? activeSuggestionId;

  /// Códigos (`sgLinha`) das linhas já acompanhadas no mapa. Também recebem o
  /// selo "Acompanhando no mapa".
  final Set<String> trackedLineCodes;

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
      return _EmptyResults(query: query, onEditSearch: onEditSearch);
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
            isActive:
                suggestion.id == activeSuggestionId ||
                trackedLineCodes.contains(suggestion.code.trim()),
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

/// Estado exibido quando a busca não encontra linhas nem paradas.
class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.query, this.onEditSearch});

  final String query;
  final VoidCallback? onEditSearch;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.search_rounded,
                size: 26,
                color: AppColors.primaryPressed,
              ),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            'Não encontramos\n“$query”',
            style: const TextStyle(
              fontSize: 28,
              height: 1.22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhuma linha ou parada corresponde à sua busca.',
            style: _emptyBodyStyle,
          ),
          const SizedBox(height: 18),
          const Text(
            'Tente outro nome, número de linha ou código de parada. '
            'Por exemplo: 101, Praça do Ipê ou P-014.',
            style: _emptyBodyStyle,
          ),
          if (onEditSearch != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              height: 46,
              child: TextButton(
                onPressed: onEditSearch,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primarySurface,
                  foregroundColor: AppColors.primaryPressed,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_rounded, size: 19),
                    SizedBox(width: 8),
                    Text(
                      'Editar busca',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          const Text(
            'Pesquisar locais, linhas e paradas não consome rastreamentos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

const _emptyBodyStyle = TextStyle(
  fontSize: 14,
  height: 1.5,
  color: AppColors.textSecondary,
);

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
