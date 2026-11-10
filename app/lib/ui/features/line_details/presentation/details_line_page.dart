import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../../di/dependencies.dart';
import '../../../../domain/models/bus_stop.dart';
import '../../../../domain/models/line.dart';
import '../../../../domain/repositories/details_line_repository.dart';
import '../../../../domain/repositories/tracking_repository.dart';
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
    this.trackingRepository,
    this.viewModel,
  });

  /// Código da linha (`sgLinha`) usada para carregar os detalhes.
  final String lineCode;

  /// Permite injetar um repositório fake em testes.
  final DetailsLineRepository? repository;

  /// Permite injetar o repositório de rastreamento em testes.
  final TrackingRepository? trackingRepository;

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
    _viewModel = widget.viewModel ?? _createViewModel();
    _viewModel.load();
  }

  DetailsLineViewModel _createViewModel() {
    if (widget.repository == null && widget.trackingRepository == null) {
      return injector.getViewModelParam<DetailsLineViewModel, String>(
        widget.lineCode,
      );
    }
    return DetailsLineViewModel(
      widget.repository ?? injector.getRepository<DetailsLineRepository>(),
      trackingRepository:
          widget.trackingRepository ??
          injector.getRepository<TrackingRepository>(),
      lineCode: widget.lineCode,
    );
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

  void _toggleStops() {
    setState(() => _showAllStops = !_showAllStops);
  }

  /// Retorna `true` para a tela que abriu os detalhes iniciar o rastreamento.
  void _startTracking() {
    if (context.canPop()) {
      context.pop(true);
      return;
    }
    context.goNamed(AppRoutes.homeName);
  }

  /// Remove a linha do mapa e volta para a tela que abriu os detalhes.
  Future<void> _stopTracking() async {
    await _viewModel.stopTracking();
    if (!mounted) {
      return;
    }
    if (context.canPop()) {
      context.pop(false);
      return;
    }
    context.goNamed(AppRoutes.homeName);
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
            AnimatedBuilder(
              animation: _viewModel,
              builder: (context, _) {
                if (_viewModel.state.line == null) {
                  return const SizedBox.shrink();
                }
                return _TrackingActionBar(
                  isTracking: _viewModel.isTracking,
                  onStart: _startTracking,
                  onStop: _stopTracking,
                );
              },
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
        isTracking: _viewModel.isTracking,
        onToggleStops: _toggleStops,
      ),
      DetailsLineNoStops(:final line) => _LineContent(
        line: line,
        stops: const [],
        isTracking: _viewModel.isTracking,
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
          const Expanded(
            child: Text(
              'Detalhes da linha',
              style: TextStyle(
                fontSize: 20,
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

class _TrackingActionBar extends StatelessWidget {
  const _TrackingActionBar({
    required this.isTracking,
    required this.onStart,
    required this.onStop,
  });

  final bool isTracking;
  final VoidCallback onStart;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isTracking)
              OutlinedButton.icon(
                onPressed: onStop,
                icon: const Icon(Icons.location_off_rounded, size: 22),
                label: const Text('Remover do mapa'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  minimumSize: const Size.fromHeight(60),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else ...[
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.directions_bus_filled_rounded, size: 22),
                label: const Text('Começar a acompanhar'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Iniciar usa 1 de 5 rastreamentos por dia.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
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
    this.isTracking = false,
    this.showAllStops = false,
    this.onToggleStops,
  });

  final Line line;
  final List<BusStop> stops;
  final bool isTracking;
  final bool showAllStops;
  final VoidCallback? onToggleStops;

  @override
  Widget build(BuildContext context) {
    final visibleStops = showAllStops
        ? stops
        : stops.take(_initialVisibleStops).toList(growable: false);
    final canToggle = stops.length > _initialVisibleStops;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      children: [
        LineDetailsHeader(line: line, isTracking: isTracking),
        const SizedBox(height: 28),
        _ItineraryHeader(line: line, count: stops.length),
        const SizedBox(height: 8),
        if (stops.isEmpty)
          const _NoStopsCard()
        else ...[
          for (var index = 0; index < visibleStops.length; index++)
            LineStopTimelineTile(
              stop: visibleStops[index],
              isFirst: index == 0,
              isLast: index == visibleStops.length - 1,
            ),
          if (canToggle && onToggleStops != null)
            _StopsToggleButton(
              showAllStops: showAllStops,
              onPressed: onToggleStops!,
            ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),
        ],
      ],
    );
  }
}

class _ItineraryHeader extends StatelessWidget {
  const _ItineraryHeader({required this.line, required this.count});

  final Line line;
  final int count;

  String get _hint {
    final origin = line.origin.trim();
    final destination = line.destination.trim();
    if (origin.isNotEmpty && origin == destination) {
      return 'Circular';
    }
    return 'Sentido de ida';
  }

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? 'parada' : 'paradas';

    return Row(
      children: [
        Expanded(
          child: Text(
            'Itinerário · $count $label',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _hint,
          style: const TextStyle(
            fontSize: 13.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _StopsToggleButton extends StatelessWidget {
  const _StopsToggleButton({
    required this.showAllStops,
    required this.onPressed,
  });

  final bool showAllStops;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(
          showAllStops ? Icons.expand_less_rounded : Icons.expand_more_rounded,
          size: 20,
        ),
        label: Text(showAllStops ? 'Mostrar menos' : 'Mostrar mais'),
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
