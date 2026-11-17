import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../di/dependencies.dart';
import '../../../../domain/models/city.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../routing/app_routes.dart';
import '../../home/presentation/widgets/map/map_search_cache.dart';
import 'select_city_view_model.dart';

/// Tela de seleção de cidade.
///
/// É exibida uma vez após o login, antes da Home, e também pode ser aberta
/// pela aba Conta no modo de troca ([isChangeMode]).
class SelectCityPage extends StatefulWidget {
  const SelectCityPage({super.key, this.viewModel, this.isChangeMode = false});

  /// Permite injetar um view model pronto em testes.
  final SelectCityViewModel? viewModel;

  /// `true` quando a tela foi aberta pela aba Conta para trocar a cidade.
  final bool isChangeMode;

  @override
  State<SelectCityPage> createState() => _SelectCityPageState();
}

class _SelectCityPageState extends State<SelectCityPage> {
  late final SelectCityViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel =
        widget.viewModel ??
        injector.getViewModelParam<SelectCityViewModel, bool>(
          widget.isChangeMode,
        );
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final confirmed = await _viewModel.confirm();
    if (!mounted || !confirmed) {
      return;
    }

    if (injector.isReady) {
      injector.getService<MapSearchCache>().clear();
    }

    if (widget.isChangeMode && context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(AppRoutes.homeName);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(AppRoutes.homeName);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.background,
      ),
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: AnimatedBuilder(
                  animation: _viewModel,
                  builder: (context, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.isChangeMode)
                          _Header(onBack: _back)
                        else
                          const SizedBox(height: 48),
                        const SizedBox(height: 24),
                        const _CityBadge(),
                        const SizedBox(height: 26),
                        Text(
                          widget.isChangeMode
                              ? 'Trocar cidade'
                              : 'Escolha sua cidade',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontSize: 28,
                                height: 1.15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.isChangeMode
                              ? 'A troca encerra o rastreamento ativo e limpa '
                                    'as buscas da cidade anterior.'
                              : 'Usaremos essa cidade para mostrar linhas, '
                                    'paradas e ônibus.',
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 26),
                        if (_viewModel.isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                              ),
                            ),
                          )
                        else if (_viewModel.cities.isEmpty)
                          SizedBox(
                            height: 320,
                            child: EmptyState(
                              icon: Icons.location_off_outlined,
                              title: 'Nenhuma cidade disponível',
                              message:
                                  _viewModel.errorMessage ??
                                  'Tente novamente em instantes.',
                              action: OutlinedButton(
                                onPressed: _viewModel.load,
                                child: const Text('Tentar novamente'),
                              ),
                            ),
                          )
                        else ...[
                          for (final city in _viewModel.cities) ...[
                            _CityCard(
                              city: city,
                              selected:
                                  _viewModel.selectedCity?.slug == city.slug,
                              onTap: () => _viewModel.choose(city),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_viewModel.errorMessage != null) ...[
                            const SizedBox(height: 4),
                            _ErrorPanel(message: _viewModel.errorMessage!),
                          ],
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _viewModel.canSubmit ? _confirm : null,
                            child: _viewModel.isSubmitting
                                ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    widget.isChangeMode
                                        ? 'Salvar cidade'
                                        : 'Continuar',
                                  ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        const Text(
                          'Você poderá trocar a cidade depois na aba Conta.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chevron_left_rounded,
                  size: 22,
                  color: AppColors.primary,
                ),
                Text(
                  'Voltar',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CityBadge extends StatelessWidget {
  const _CityBadge();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.location_city_rounded,
          size: 26,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _CityCard extends StatelessWidget {
  const _CityCard({
    required this.city,
    required this.selected,
    required this.onTap,
  });

  final City city;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: 'Cidade ${city.label}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySurface : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 22,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      city.label,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      city.timezone,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 24,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.dangerAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
