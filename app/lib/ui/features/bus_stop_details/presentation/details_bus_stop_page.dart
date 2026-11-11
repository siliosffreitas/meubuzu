import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../di/dependencies.dart';
import '../../../../domain/models/bus_stop.dart';
import '../../../../domain/models/line.dart';
import '../../../../domain/repositories/details_bus_stop_repository.dart';
import '../../../../domain/repositories/tracking_repository.dart';
import '../../../../domain/repositories/user_location_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/details_top_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../routing/app_routes.dart';
import 'details_bus_stop_state.dart';
import 'details_bus_stop_view_model.dart';
import 'widgets/bus_stop_details_header.dart';
import 'widgets/bus_stop_line_tile.dart';
import 'widgets/bus_stop_map_preview.dart';

/// Constrói a prévia do mapa exibida no cabeçalho da tela.
typedef BusStopMapPreviewBuilder = Widget Function(BusStop busStop);

/// Tela com os detalhes da parada e as linhas que passam por ela.
class DetailsBusStopPage extends StatefulWidget {
  const DetailsBusStopPage({
    super.key,
    required this.busStopCode,
    this.repository,
    this.locationRepository,
    this.trackingRepository,
    this.viewModel,
    this.mapPreviewBuilder,
  });

  /// Código da parada usado para carregar os detalhes.
  final String busStopCode;

  /// Permite injetar um repositório fake em testes.
  final DetailsBusStopRepository? repository;

  /// Permite injetar a localização em testes.
  final UserLocationRepository? locationRepository;

  /// Permite injetar o rastreamento em testes.
  final TrackingRepository? trackingRepository;

  /// Permite injetar um view model pronto em testes.
  final DetailsBusStopViewModel? viewModel;

  /// Permite substituir o mapa real nos testes.
  final BusStopMapPreviewBuilder? mapPreviewBuilder;

  @override
  State<DetailsBusStopPage> createState() => _DetailsBusStopPageState();
}

class _DetailsBusStopPageState extends State<DetailsBusStopPage> {
  late final DetailsBusStopViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel ?? _createViewModel();
    _viewModel.load();
  }

  DetailsBusStopViewModel _createViewModel() {
    if (widget.repository == null &&
        widget.locationRepository == null &&
        widget.trackingRepository == null) {
      return injector.getViewModelParam<DetailsBusStopViewModel, String>(
        widget.busStopCode,
      );
    }
    return DetailsBusStopViewModel(
      widget.repository ?? injector.getRepository<DetailsBusStopRepository>(),
      busStopCode: widget.busStopCode,
      locationRepository: widget.locationRepository,
      trackingRepository: widget.trackingRepository,
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
    _viewModel.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            DetailsTopBar(title: 'Detalhes da parada', onBack: _back),
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

  Widget _buildContent(DetailsBusStopState state) {
    return switch (state) {
      DetailsBusStopIdle() => const _LoadingView(),
      DetailsBusStopLoading() => const _LoadingView(),
      DetailsBusStopReady(:final busStop, :final lines) => _BusStopContent(
        busStop: busStop,
        lines: lines,
        distanceInMeters: _viewModel.distanceInMeters,
        mapPreview: (widget.mapPreviewBuilder ?? _defaultMapPreview).call(
          busStop,
        ),
        trackingLines: _viewModel.trackedLineCodes,
      ),
      DetailsBusStopNotFound() => _NotFoundView(
        busStopCode: widget.busStopCode,
        onBack: _back,
      ),
      DetailsBusStopError() => _ErrorView(onRetry: _reload),
    };
  }

  Widget _defaultMapPreview(BusStop busStop) {
    return BusStopMapPreview(busStop: busStop);
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
            'Carregando parada...',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _BusStopContent extends StatelessWidget {
  const _BusStopContent({
    required this.busStop,
    required this.lines,
    required this.distanceInMeters,
    required this.mapPreview,
    required this.trackingLines,
  });

  final BusStop busStop;
  final List<Line> lines;
  final double? distanceInMeters;
  final Widget mapPreview;
  final Set<String> trackingLines;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        BusStopDetailsHeader(
          busStop: busStop,
          distanceInMeters: distanceInMeters,
        ),
        const SizedBox(height: 20),
        mapPreview,
        const SizedBox(height: 26),
        _LinesHeader(count: lines.length),
        const SizedBox(height: 12),
        if (lines.isEmpty)
          const _NoLinesCard()
        else
          for (var index = 0; index < lines.length; index++) ...[
            if (index > 0) const SizedBox(height: 10),
            BusStopLineTileWithNavigation(
              line: lines[index],
              trackingLines: trackingLines,
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _LinesHeader extends StatelessWidget {
  const _LinesHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Linhas que passam aqui',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (count > 0)
          Text(
            count == 1 ? '1 linha' : '$count linhas',
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}

class _NoLinesCard extends StatelessWidget {
  const _NoLinesCard();

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
              'Nenhuma linha cadastrada para esta parada no momento.',
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
  const _NotFoundView({required this.busStopCode, required this.onBack});

  final String busStopCode;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final code = busStopCode.trim();
    return EmptyState(
      icon: Icons.search_off_rounded,
      title: 'Parada não encontrada',
      message: code.isEmpty
          ? 'Não encontramos esta parada no catálogo. Confira o código e tente '
                'novamente.'
          : 'Não encontrou a parada $code no catálogo. Confira o código e '
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
      title: 'Não foi possível carregar a parada',
      message:
          'Verifique sua conexão e tente novamente para ver as linhas que '
          'passam por aqui.',
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 20),
        label: const Text('Tentar novamente'),
      ),
    );
  }
}
