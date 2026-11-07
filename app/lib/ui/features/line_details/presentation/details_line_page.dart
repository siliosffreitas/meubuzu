import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../../di/dependencies.dart';
import '../../../../domain/models/bus_stop.dart';
import '../../../../domain/models/line.dart';
import '../../../../domain/repositories/details_line_repository.dart';
import '../../../routing/app_routes.dart';
import 'details_line_state.dart';
import 'details_line_view_model.dart';
import 'widgets/line_details_header.dart';
import 'widgets/line_stop_timeline_tile.dart';

/// Quantidade de paradas exibidas antes do botão "Mostrar mais".
const _initialVisibleStops = 3;

/// Tela com os detalhes da linha e a lista ordenada de suas paradas.
class DetailsLinePage extends StatefulWidget {
  const DetailsLinePage({
    super.key,
    required this.lineCode,
    this.repository,
    this.viewModel,
  });

  /// Código da linha (`sgLinha`) usada para carregar os detalhes.
  final String lineCode;

  /// Permite injetar um repositório fake em testes.
  final DetailsLineRepository? repository;

  /// Permite injetar um view model pronto em testes.
  final DetailsLineViewModel? viewModel;

  @override
  State<DetailsLinePage> createState() => _DetailsLinePageState();
}

class _DetailsLinePageState extends State<DetailsLinePage> {
  late final DetailsLineViewModel _viewModel;
  bool _showAllStops = false;

  @override
  void initState() {
    super.initState();
    _viewModel =
        widget.viewModel ??
        (widget.repository != null
            ? DetailsLineViewModel(
                widget.repository!,
                lineCode: widget.lineCode,
              )
            : injector.getViewModelParam<DetailsLineViewModel, String>(
                widget.lineCode,
              ));
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  /// Volta para a tela anterior ou, em acesso direto, para a Home.
  void _back() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(AppRoutes.homeName);
  }

  void _reload() {
    setState(() => _showAllStops = false);
    _viewModel.load();
  }

  void _showMoreStops() {
    if (_showAllStops) {
      return;
    }
    setState(() => _showAllStops = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onBack: _back),
            Expanded(
              child: AnimatedBuilder(
                animation: _viewModel,
                builder: (context, _) {
                  return _buildContent(_viewModel.state);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(DetailsLineState state) {
    return switch (state) {
      DetailsLineIdle() => const _LoadingView(),
      DetailsLineLoading() => const _LoadingView(),
      DetailsLineReady(:final line, :final stops) => _LineContent(
        line: line,
        stops: stops,
        showAllStops: _showAllStops,
        onShowMore: _showMoreStops,
      ),
      DetailsLineNoStops(:final line) => _LineContent(
        line: line,
        stops: const [],
      ),
      DetailsLineNotFound() => _NotFoundView(
        lineCode: widget.lineCode,
        onBack: _back,
      ),
      DetailsLineError() => _ErrorView(onRetry: _reload),
    };
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: 'Voltar',
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Detalhes da linha',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Carregando linha...',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _LineContent extends StatelessWidget {
  const _LineContent({
    required this.line,
    required this.stops,
    this.showAllStops = false,
    this.onShowMore,
  });

  final Line line;
  final List<BusStop> stops;
  final bool showAllStops;
  final VoidCallback? onShowMore;

  @override
  Widget build(BuildContext context) {
    final visibleStops = showAllStops
        ? stops
        : stops.take(_initialVisibleStops).toList(growable: false);
    final hasHiddenStops = visibleStops.length < stops.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        LineDetailsHeader(line: line),
        const SizedBox(height: 24),
        _StopsSectionTitle(count: stops.length),
        const SizedBox(height: 10),
        if (stops.isEmpty)
          const _NoStopsCard()
        else ...[
          for (var index = 0; index < visibleStops.length; index++)
            LineStopTimelineTile(
              stop: visibleStops[index],
              position: index + 1,
              isFirst: index == 0,
              isLast: index == stops.length - 1,
            ),
          if (hasHiddenStops && onShowMore != null)
            _ShowMoreButton(onPressed: onShowMore!),
          const SizedBox(height: 16),
          const _OrderNotice(),
        ],
      ],
    );
  }
}

class _StopsSectionTitle extends StatelessWidget {
  const _StopsSectionTitle({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paradas da linha',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Na ordem do itinerário',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryPressed,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShowMoreButton extends StatelessWidget {
  const _ShowMoreButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.expand_more_rounded, size: 20),
        label: const Text('Mostrar mais'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _NoStopsCard extends StatelessWidget {
  const _NoStopsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.route_outlined, size: 22, color: AppColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nenhuma parada cadastrada para esta linha no momento.',
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderNotice extends StatelessWidget {
  const _OrderNotice();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMuted),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'As paradas são exibidas na ordem em que a linha passa por elas.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView({required this.lineCode, required this.onBack});

  final String lineCode;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.search_off_rounded,
      title: 'Linha não encontrada',
      message:
          'Não encontramos a linha $lineCode no catálogo. Confira o código e '
          'tente novamente.',
      action: OutlinedButton.icon(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_rounded, size: 19),
        label: const Text('Voltar'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Não foi possível carregar a linha',
      message:
          'Verifique sua conexão e tente novamente para ver as paradas da '
          'linha.',
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 20),
        label: const Text('Tentar novamente'),
      ),
    );
  }
}
