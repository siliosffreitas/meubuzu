import 'package:flutter/material.dart';

import '../../../../../../core/extensions/line_direction_label.dart';
import '../../../../../../core/extensions/line_map_color.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../../domain/models/tracked_line.dart';
import '../map_tracking_polylines.dart';
import 'direction_selection_sheet.dart';

/// Painel flutuante com todas as linhas acompanhadas no mapa.
///
/// Pode ser minimizado pelo toque no cabeçalho ou pelo arraste da alça. O
/// estado de minimização é local da UI; os dados das linhas vêm do
/// [MapTrackingViewModel] por parâmetro.
class TrackingPanel extends StatefulWidget {
  const TrackingPanel({
    super.key,
    required this.trackedLines,
    this.updatedAt,
    this.initiallyCollapsed = false,
    this.onLineTap,
    this.onRemoveLine,
    this.onDirectionSelected,
  });

  /// Linhas retornadas pelo view model de rastreamento.
  final List<TrackedLine> trackedLines;

  /// Momento da última atualização do rastreamento.
  final DateTime? updatedAt;

  /// Permite abrir o painel já minimizado.
  final bool initiallyCollapsed;

  /// Chamado ao tocar em uma linha, normalmente para abrir seus detalhes.
  final ValueChanged<TrackedLine>? onLineTap;

  /// Chamado ao arrastar uma linha para o lado, para encerrar o rastreamento.
  final ValueChanged<TrackedLine>? onRemoveLine;

  /// Chamado ao selecionar outro itinerário no modal de sentidos.
  ///
  /// O painel mostra um indicador de carregamento enquanto a ação termina.
  final Future<void> Function(TrackedLine tracked, int direction)?
  onDirectionSelected;

  @override
  State<TrackingPanel> createState() => _TrackingPanelState();
}

class _TrackingPanelState extends State<TrackingPanel> {
  static const _animationDuration = Duration(milliseconds: 220);
  static const _minListHeight = 120.0;
  static const _maxListHeight = 300.0;

  late bool _isCollapsed = widget.initiallyCollapsed;
  final Set<String> _changingDirections = <String>{};

  bool get _hasLines => widget.trackedLines.isNotEmpty;

  void _toggle() {
    if (!_hasLines) {
      return;
    }
    setState(() => _isCollapsed = !_isCollapsed);
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -80 && _isCollapsed) {
      setState(() => _isCollapsed = false);
    } else if (velocity > 80 && !_isCollapsed) {
      setState(() => _isCollapsed = true);
    }
  }

  /// Abre o seletor de sentidos mesmo quando há apenas um itinerário.
  ///
  /// Sem nenhum itinerário, o modal mostra o estado vazio e nenhuma troca é
  /// solicitada.
  Future<void> _openDirectionSheet(TrackedLine tracked) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DirectionSelectionSheet(tracked: tracked),
    );
    if (selected == null || selected == tracked.direction) {
      return;
    }

    final onDirectionSelected = widget.onDirectionSelected;
    if (onDirectionSelected == null || !mounted) {
      return;
    }

    final key = trackedLineKey(tracked);
    setState(() => _changingDirections.add(key));
    try {
      await onDirectionSelected(tracked, selected);
    } finally {
      if (mounted) {
        setState(() => _changingDirections.remove(key));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasLines) {
      return const SizedBox.shrink();
    }

    final listMaxHeight = (MediaQuery.sizeOf(context).height * 0.32)
        .clamp(_minListHeight, _maxListHeight)
        .toDouble();
    final positions = [
      for (final tracked in widget.trackedLines) ...tracked.busPositions,
    ];
    final hasDemo = positions.any((position) => position.dataMode == 'demo');
    final hasStale = positions.any((position) => position.isStale);

    return Material(
      key: const Key('tracking-panel'),
      color: Colors.white,
      elevation: 16,
      shadowColor: const Color(0x242E3C3E),
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Handle(
            isCollapsed: _isCollapsed,
            onTap: _toggle,
            onVerticalDragEnd: _handleDragEnd,
          ),
          _Header(
            count: widget.trackedLines.length,
            updatedAt: widget.updatedAt,
            onTap: _toggle,
          ),
          if (hasDemo || hasStale)
            _TrackingNotice(hasDemo: hasDemo, hasStale: hasStale),
          AnimatedSize(
            duration: _animationDuration,
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _isCollapsed
                ? const SizedBox(width: double.infinity)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(height: 1, color: AppColors.border),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: listMaxHeight),
                        child: ListView.separated(
                          key: const Key('tracking-panel-list'),
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: widget.trackedLines.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            indent: 20,
                            endIndent: 20,
                            color: AppColors.border,
                          ),
                          itemBuilder: (context, index) {
                            final tracked = widget.trackedLines[index];
                            return Dismissible(
                              key: Key(
                                'tracking-dismiss-${trackedLineKey(tracked)}',
                              ),
                              direction: DismissDirection.endToStart,
                              background: const _DismissBackground(),
                              onDismissed: (_) =>
                                  widget.onRemoveLine?.call(tracked),
                              child: Semantics(
                                label: 'Arraste para a esquerda para remover '
                                    'do rastreamento',
                                child: _TrackedLineTile(
                                  tracked: tracked,
                                  onTap: widget.onLineTap,
                                  onDirectionTap: () =>
                                      _openDirectionSheet(tracked),
                                  isChangingDirection: _changingDirections
                                      .contains(trackedLineKey(tracked)),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({
    required this.isCollapsed,
    required this.onTap,
    required this.onVerticalDragEnd,
  });

  final bool isCollapsed;
  final VoidCallback onTap;
  final ValueChanged<DragEndDetails> onVerticalDragEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('tracking-panel-handle'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onVerticalDragEnd: onVerticalDragEnd,
      child: Semantics(
        button: true,
        label: isCollapsed
            ? 'Expandir linhas no mapa'
            : 'Minimizar linhas no mapa',
        child: SizedBox(
          height: 24,
          child: Center(
            child: Container(
              width: 42,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.updatedAt,
    required this.onTap,
  });

  final int count;
  final DateTime? updatedAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? '1 LINHA NO MAPA' : '$count LINHAS NO MAPA';
    final updatedAt = this.updatedAt;

    return InkWell(
      key: const Key('tracking-panel-header'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.primaryPressed,
                ),
              ),
            ),
            if (updatedAt != null)
              Text(
                'Atualizado ${_formatTime(updatedAt)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrackingNotice extends StatelessWidget {
  const _TrackingNotice({required this.hasDemo, required this.hasStale});

  final bool hasDemo;
  final bool hasStale;

  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      if (hasDemo) 'Dados de demonstração',
      if (hasStale) 'Posições antigas',
    ];

    return Container(
      key: const Key('tracking-panel-notice'),
      color: AppColors.attentionSurface,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(
        labels.join(' · '),
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Fundo exibido enquanto a linha é arrastada para fora da lista.
class _DismissBackground extends StatelessWidget {
  const _DismissBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('tracking-dismiss-background'),
      color: AppColors.danger,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Icon(
        Icons.delete_rounded,
        size: 22,
        color: Colors.white,
      ),
    );
  }
}

class _TrackedLineTile extends StatelessWidget {
  const _TrackedLineTile({
    required this.tracked,
    this.onTap,
    this.onDirectionTap,
    this.isChangingDirection = false,
  });

  final TrackedLine tracked;
  final ValueChanged<TrackedLine>? onTap;
  final VoidCallback? onDirectionTap;
  final bool isChangingDirection;

  @override
  Widget build(BuildContext context) {
    final line = tracked.line;
    final subtitle = trackingLineSubtitle(tracked);
    final onTap = this.onTap;

    return InkWell(
      key: Key('tracking-line-tile-${trackedLineKey(tracked)}'),
      onTap: onTap == null ? null : () => onTap(tracked),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(
          children: [
            _LineBadge(code: trackedLineKey(tracked), color: line.mapColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    InkWell(
                      key: Key(
                        'tracking-line-direction-${trackedLineKey(tracked)}',
                      ),
                      onTap: onDirectionTap,
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          if (isChangingDirection)
                            const SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          else
                            const Icon(
                              Icons.swap_horiz_rounded,
                              size: 15,
                              color: AppColors.primary,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineBadge extends StatelessWidget {
  const _LineBadge({required this.code, required this.color});

  final String code;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('tracking-line-badge-$code'),
      constraints: const BoxConstraints(minWidth: 66),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.directions_bus_filled_rounded,
            size: 15,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            code,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Texto secundário da linha no painel.
///
/// Usa o rótulo do sentido selecionado quando o catálogo informou itinerários.
/// Sem nenhum itinerário, deixa isso explícito — o modal abre em estado vazio.
String trackingLineSubtitle(TrackedLine tracked) {
  final label = tracked.currentDirection?.label.trim();
  if (label != null && label.isNotEmpty) {
    return label;
  }
  if (tracked.directions.isNotEmpty) {
    return tracked.line.directionLabel;
  }
  return 'Itinerário não disponível';
}

String _formatTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(value.hour)}:${twoDigits(value.minute)}:'
      '${twoDigits(value.second)}';
}
