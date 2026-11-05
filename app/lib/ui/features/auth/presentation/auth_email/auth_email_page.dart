import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../../domain/repositories/auth_repository.dart';
import '../../../../../di/dependencies.dart';
import '../../../../routing/app_routes.dart';
import 'auth_email_view_model.dart';

/// Primeira etapa do fluxo de autenticação: coleta do e-mail.
class AuthEmailPage extends StatefulWidget {
  const AuthEmailPage({super.key, this.repository, this.viewModel});

  /// Permite injetar um repositório fake em testes.
  final AuthRepository? repository;

  /// Permite injetar um view model pronto em testes.
  final AuthEmailViewModel? viewModel;

  @override
  State<AuthEmailPage> createState() => _AuthEmailPageState();
}

class _AuthEmailPageState extends State<AuthEmailPage> {
  final _emailController = TextEditingController();
  late final AuthEmailViewModel _viewModel;
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _viewModel =
        widget.viewModel ??
        (widget.repository != null
            ? AuthEmailViewModel(widget.repository!)
            : injector.getViewModel<AuthEmailViewModel>());
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _showInfo('Termos de uso');
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _showInfo('Política de privacidade');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _viewModel.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _showInfo(String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label em breve.')));
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final sent = await _viewModel.submit();
    if (!mounted || !sent) {
      return;
    }
    await context.pushNamed(
      AppRoutes.authCodeName,
      extra: _viewModel.email.trim(),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: AnimatedBuilder(
                  animation: _viewModel,
                  builder: (context, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _BrandHeader(),
                        const SizedBox(height: 28),
                        const _HeroCard(),
                        const SizedBox(height: 32),
                        Text(
                          'Menos espera.\nMais caminho.',
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                fontSize: 34,
                                height: 1.15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.6,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Consulte seu ônibus no mapa e organize sua próxima '
                          'saída.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontSize: 15.5,
                                height: 1.45,
                                color: AppColors.textSecondary,
                              ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Seu e-mail',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _emailController,
                          enabled: !_viewModel.isSubmitting,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.email],
                          autocorrect: false,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'voce@exemplo.com',
                            errorText: _viewModel.errorMessage,
                            helperText: _viewModel.errorMessage == null
                                ? 'Enviaremos um código temporário para entrar. '
                                      'Você não precisa criar uma senha.'
                                : null,
                            helperMaxLines: 2,
                          ),
                          onChanged: _viewModel.setEmail,
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _viewModel.isSubmitting ? null : _submit,
                          child: _viewModel.isSubmitting
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.arrow_forward_rounded, size: 20),
                                    SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        'Receber código por e-mail',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 20),
                        Text.rich(
                          TextSpan(
                            style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.5,
                              color: AppColors.textSecondary,
                            ),
                            children: [
                              const TextSpan(
                                text: 'Ao continuar, você concorda com os ',
                              ),
                              TextSpan(
                                text: 'Termos de uso',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: _termsRecognizer,
                              ),
                              const TextSpan(text: ' e a '),
                              TextSpan(
                                text: 'Política de privacidade',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: _privacyRecognizer,
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        const _TrialNote(),
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

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.directions_bus_filled_rounded,
            size: 20,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'MeuBuzu',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          const Expanded(flex: 5, child: _BusIllustration()),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              'Seu caminho,\nmais claro.',
              style: TextStyle(
                fontSize: 20,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusIllustration extends StatelessWidget {
  const _BusIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 78,
            height: 78,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x14357872),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_bus_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          Positioned(
            bottom: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dash(AppColors.primary.withValues(alpha: 0.35)),
                const SizedBox(width: 5),
                _dash(AppColors.primary.withValues(alpha: 0.55)),
                const SizedBox(width: 5),
                _dash(AppColors.primary),
                const SizedBox(width: 5),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dash(Color color) {
    return Container(
      width: 10,
      height: 3,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _TrialNote extends StatelessWidget {
  const _TrialNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.timelapse_rounded,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 6),
        const Flexible(
          child: Text(
            'Novos usuários podem testar por 7 dias.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
