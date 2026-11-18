import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../../data/models/place_suggestion.dart';
import '../../../../../../di/dependencies.dart';
import '../../../../../../domain/repositories/favorites_repository.dart';
import '../../../../../../domain/repositories/place_search_repository.dart';
import '../../../../../../domain/repositories/tracking_repository.dart';
import 'map_search_view_model.dart';
import 'widgets/search_results_panel.dart';

/// Tela dedicada para procurar linhas e paradas.
///
/// Ao escolher uma sugestão, fecha a tela devolvendo o item selecionado para
/// que o mapa exiba o marcador correspondente.
class MapSearchPage extends StatefulWidget {
  const MapSearchPage({
    super.key,
    this.repository,
    this.trackingRepository,
    this.favoritesRepository,
    this.viewModel,
    this.activeSuggestionId,
  });

  /// Permite injetar um repositório de busca fake em testes.
  final PlaceSearchRepository? repository;

  /// Permite injetar um repositório de rastreamento fake em testes.
  final TrackingRepository? trackingRepository;

  /// Permite injetar um repositório de favoritos fake em testes.
  final FavoritesRepository? favoritesRepository;

  /// Permite injetar um view model pronto em testes.
  final MapSearchViewModel? viewModel;

  /// Linha atualmente exibida no mapa, destacada na lista de resultados.
  final String? activeSuggestionId;

  @override
  State<MapSearchPage> createState() => _MapSearchPageState();
}

class _MapSearchPageState extends State<MapSearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late final MapSearchViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel =
        widget.viewModel ??
        (widget.repository != null
            ? MapSearchViewModel(
                widget.repository!,
                trackingRepository: widget.trackingRepository,
                favoritesRepository: widget.favoritesRepository,
              )
            : injector.getViewModel<MapSearchViewModel>());

    // Restaura a última busca concluída ao reabrir a tela.
    _controller.text = _viewModel.query;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    _viewModel.clear();
    _focusNode.requestFocus();
  }

  /// Devolve o foco ao campo mantendo a consulta para o usuário ajustá-la.
  void _editSearch() {
    _focusNode.requestFocus();
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  void _selectSuggestion(PlaceSuggestion suggestion) {
    context.pop(suggestion);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    tooltip: 'Voltar',
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _SearchField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: _viewModel.setQuery,
                      onClear: _clear,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _viewModel,
                builder: (context, _) {
                  if (!_viewModel.hasQuery) {
                    return const _SearchIntro();
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: SearchResultsPanel(
                      query: _viewModel.query.trim(),
                      isLoading: _viewModel.isLoading,
                      results: _viewModel.results,
                      maxHeight: double.infinity,
                      activeSuggestionId: widget.activeSuggestionId,
                      trackedLineCodes: _viewModel.trackedLineCodes,
                      favoriteLineIds: _viewModel.favoriteLineIds,
                      onFavoriteTap: _viewModel.hasFavorites
                          ? _viewModel.toggleFavorite
                          : null,
                      onSelected: _selectSuggestion,
                      onEditSearch: _editSearch,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: const Color(0x142E3C3E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(
              Icons.search_rounded,
              size: 22,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                autocorrect: false,
                style: const TextStyle(
                  fontSize: 15.5,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Buscar linha ou parada',
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                if (controller.text.isEmpty) {
                  return const SizedBox(width: 14);
                }
                return IconButton(
                  onPressed: onClear,
                  tooltip: 'Limpar busca',
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Conteúdo exibido enquanto o usuário ainda não digitou uma busca.
class _SearchIntro extends StatelessWidget {
  const _SearchIntro();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.travel_explore_rounded,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Encontre sua linha ou parada',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Digite o número da linha, o nome da parada ou um endereço '
              'para ver os resultados no mapa.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
