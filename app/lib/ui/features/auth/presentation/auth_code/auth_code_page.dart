import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../../data/repositories/auth_repository.dart';
import '../../../../routing/app_routes.dart';
import 'auth_code_view_model.dart';

/// Segunda etapa do fluxo: confirmação do código enviado por e-mail.
class AuthCodePage extends StatefulWidget {
  const AuthCodePage({
    super.key,
    required this.email,
    required this.repository,
  });

  final String email;
  final AuthRepository repository;

  @override
  State<AuthCodePage> createState() => _AuthCodePageState();
}

class _AuthCodePageState extends State<AuthCodePage> {
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();
  late final AuthCodeViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AuthCodeViewModel(widget.repository, email: widget.email);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _codeFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    FocusScope.of(context).unfocus();
    final confirmed = await _viewModel.confirm();
    if (!mounted || !confirmed) {
      return;
    }
    context.goNamed(AppRoutes.homeName);
  }

  Future<void> _resend() async {
    final sent = await _viewModel.resend();
    if (!mounted || !sent) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Novo código enviado para ${widget.email}.')),
      );
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 32,
                      ),
                      child: IntrinsicHeight(
                        child: AnimatedBuilder(
                          animation: _viewModel,
                          builder: (context, _) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const _Header(),
                                const SizedBox(height: 38),
                                const _MailBadge(),
                                const SizedBox(height: 26),
                                Text(
                                  'Confira seu e-mail',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        fontSize: 28,
                                        height: 1.15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.5,
                                        color: AppColors.textPrimary,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Enviamos um código temporário de 6 dígitos '
                                  'para:',
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.45,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  widget.email,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.45,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).maybePop(),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      textStyle: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    child: const Text('Alterar e-mail'),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                const Text(
                                  'Código de acesso',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _CodeInput(
                                  controller: _codeController,
                                  focusNode: _codeFocusNode,
                                  enabled: !_viewModel.isSubmitting,
                                  hasError: _viewModel.errorMessage != null,
                                  onChanged: _viewModel.setCode,
                                  onSubmitted: (_) => _confirm(),
                                ),
                                if (_viewModel.errorMessage != null) ...[
                                  const SizedBox(height: 20),
                                  _CodeErrorPanel(
                                    title: _viewModel.errorTitle,
                                    message: _viewModel.errorMessage!,
                                  ),
                                ] else ...[
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Use o código mais recente enviado ao '
                                    'seu e-mail.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                FilledButton(
                                  onPressed: _viewModel.isBusy
                                      ? null
                                      : _confirm,
                                  child: _viewModel.isSubmitting
                                      ? const SizedBox.square(
                                          dimension: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _viewModel.errorMessage != null
                                              ? 'Tentar novamente'
                                              : 'Confirmar código',
                                        ),
                                ),
                                const SizedBox(height: 20),
                                FilledButton(
                                  onPressed: _viewModel.isBusy ? null : _resend,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.surface,
                                    foregroundColor: AppColors.primary,
                                    disabledBackgroundColor: AppColors.surface,
                                    disabledForegroundColor:
                                        AppColors.surfaceMuted,
                                  ),
                                  child: _viewModel.isResending
                                      ? const SizedBox.square(
                                          dimension: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : const Text('Reenviar código'),
                                ),
                                const Spacer(),
                                const SizedBox(height: 24),
                                const Text(
                                  'Não chegou? Confira também a pasta de spam.',
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
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).maybePop(),
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
        const SizedBox(width: 20),
        const Expanded(
          child: Text(
            'Acesso por e-mail',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _MailBadge extends StatelessWidget {
  const _MailBadge();

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
          Icons.mail_outline_rounded,
          size: 24,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _CodeInput extends StatelessWidget {
  const _CodeInput({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hasError,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, focusNode]),
      builder: (context, _) {
        final code = controller.text;
        return Semantics(
          label: 'Código de acesso de 6 dígitos',
          textField: true,
          child: Stack(
            children: [
              Row(
                children: List.generate(6, (index) {
                  final digit = index < code.length ? code[index] : null;
                  final isActive =
                      focusNode.hasFocus &&
                      (index == code.length ||
                          (code.length == 6 && index == 5));
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: index == 5 ? 0 : 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: hasError
                              ? AppColors.dangerSurface
                              : digit != null
                              ? AppColors.surface
                              : AppColors.codeField,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: hasError
                                ? AppColors.dangerAccent
                                : isActive
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          digit ?? '–',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    showCursor: false,
                    enableInteractiveSelection: false,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration.collapsed(
                      hintText: '',
                    ),
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Painel de erro do código, com ícone, título opcional e orientação.
class _CodeErrorPanel extends StatelessWidget {
  const _CodeErrorPanel({required this.title, required this.message});

  final String? title;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
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
