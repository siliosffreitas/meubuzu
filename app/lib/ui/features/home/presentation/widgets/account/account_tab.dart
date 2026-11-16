import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/tab_header.dart';
import '../../../../../../di/dependencies.dart';
import 'account_view_model.dart';

/// Aba de conta com a identidade da sessão e a saída do aplicativo.
class AccountTab extends StatefulWidget {
  const AccountTab({super.key, this.viewModel});

  /// Permite injetar um view model pronto em testes.
  final AccountViewModel? viewModel;

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  late final AccountViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel ?? injector.getViewModel<AccountViewModel>();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: AnimatedBuilder(
            animation: _viewModel,
            builder: (context, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const TabHeader(
                    title: 'Conta',
                    subtitle: 'Seus dados e assinatura.',
                  ),
                  const SizedBox(height: 24),
                  _AccountCard(
                    email: _viewModel.email ?? 'Conta sem sessão',
                    accessLabel: _accessLabel(_viewModel.accessLevel),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _viewModel.isLoggingOut
                        ? null
                        : _viewModel.logout,
                    icon: _viewModel.isLoggingOut
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Icon(Icons.logout_rounded, size: 20),
                    label: Text(
                      _viewModel.isLoggingOut ? 'Saindo...' : 'Sair da conta',
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static String _accessLabel(String accessLevel) {
    return switch (accessLevel) {
      'paid' => 'Assinatura mensal',
      'trial' => 'Teste de 7 dias',
      'read_only' => 'Somente leitura',
      _ => 'Catálogo somente leitura',
    };
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.email, required this.accessLabel});

  final String email;
  final String accessLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 24,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  accessLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
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
