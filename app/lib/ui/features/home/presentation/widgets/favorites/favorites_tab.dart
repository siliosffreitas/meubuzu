import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/tab_header.dart';
import '../../../../../../di/dependencies.dart';
import '../../../../../../domain/models/favorite.dart';
import '../../../../../../domain/repositories/favorites_repository.dart';
import '../../../../../routing/app_routes.dart';
import 'favorites_state.dart';
import 'favorites_view_model.dart';
import 'widgets/favorite_line_tile.dart';

/// Aba de linhas favoritas da conta.
///
/// A lista é buscada no backend cada vez que a aba passa a ser exibida.
class FavoritesTab extends StatefulWidget {
  const FavoritesTab({
    super.key,
    required this.onExplore,
    this.isSelected = false,
    this.viewModel,
    this.favoritesRepository,
  });

  /// Ação do estado vazio: volta para a aba Mapa.
  final VoidCallback onExplore;

  /// Indica que a aba está visível no `IndexedStack` da Home.
  final bool isSelected;

  /// Permite injetar um view model pronto em testes.
  final FavoritesViewModel? viewModel;

  /// Permite injetar um repositório fake em testes.
  final FavoritesRepository? favoritesRepository;

  @override
  State<FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<FavoritesTab>
    with WidgetsBindingObserver {
  late final FavoritesViewModel _viewModel;
  bool _ownsViewModel = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final injected = widget.viewModel;
    if (injected != null) {
      _viewModel = injected;
    } else {
      _viewModel = FavoritesViewModel(
        widget.favoritesRepository ??
            injector.getRepository<FavoritesRepository>(),
      );
      _ownsViewModel = true;
    }
    if (widget.isSelected) {
      _viewModel.load();
    }
  }

  @override
  void didUpdateWidget(covariant FavoritesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _viewModel.load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isSelected) {
      _viewModel.load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  Future<void> _openFavorite(Favorite favorite) async {
    await context.pushNamed(
      AppRoutes.detailsLineName,
      pathParameters: {'code': favorite.displayCode},
    );
    if (mounted) {
      _viewModel.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    _showToggleError(context);

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TabHeader(
                title: 'Favoritos',
                subtitle: 'Suas linhas sempre à mão.',
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: _viewModel,
                  builder: (context, _) => _buildContent(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showToggleError(BuildContext context) {
    final message = _viewModel.errorMessage;
    if (message == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _viewModel.errorMessage != message) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      _viewModel.clearError();
    });
  }

  Widget _buildContent(BuildContext context) {
    return switch (_viewModel.state) {
      FavoritesInitial() || FavoritesLoading() => const Center(
        child: SizedBox.square(
          dimension: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppColors.primary,
          ),
        ),
      ),
      FavoritesError(:final message) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Não foi possível carregar',
        message: message,
        action: OutlinedButton.icon(
          onPressed: _viewModel.load,
          icon: const Icon(Icons.refresh_rounded, size: 19),
          label: const Text('Tentar novamente'),
        ),
      ),
      FavoritesReady() => _buildList(context),
    };
  }

  Widget _buildList(BuildContext context) {
    final groups = _viewModel.groupedByCity;
    if (groups.isEmpty) {
      return EmptyState(
        icon: Icons.star_outline_rounded,
        title: 'Nenhuma linha favorita',
        message: 'Favorite uma linha para acessá-la rapidamente na aba Mapa.',
        action: OutlinedButton.icon(
          onPressed: widget.onExplore,
          icon: const Icon(Icons.map_outlined, size: 19),
          label: const Text('Ir para o mapa'),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
            child: Text(
              entry.key,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: AppColors.primaryPressed,
              ),
            ),
          ),
          for (final favorite in entry.value) ...[
            FavoriteLineTile(
              favorite: favorite,
              onOpen: () => _openFavorite(favorite),
              onRemove: () => _viewModel.toggle(
                    favorite.displayCode,
                    citySlug: favorite.citySlug,
                  ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}
