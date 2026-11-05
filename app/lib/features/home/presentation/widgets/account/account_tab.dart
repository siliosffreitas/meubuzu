import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/tab_header.dart';

/// Aba de conta. A gestão de dados, plano e assinatura entra nas próximas
/// etapas.
class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              TabHeader(title: 'Conta', subtitle: 'Seus dados e assinatura.'),
              Expanded(
                child: EmptyState(
                  icon: Icons.person_outline_rounded,
                  title: 'Área da conta em construção',
                  message:
                      'Em breve você poderá gerenciar seus dados, seu plano e '
                      'sua assinatura por aqui.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
