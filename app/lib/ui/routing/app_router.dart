import 'package:go_router/go_router.dart';

import '../../data/repositories/auth_repository.dart';
import '../features/auth/presentation/auth_code/auth_code_page.dart';
import '../features/auth/presentation/auth_email/auth_email_page.dart';
import '../features/home/presentation/home_page.dart';
import 'app_routes.dart';

/// Configura as rotas do aplicativo com GoRouter.
///
/// A Home é a rota inicial (`/`) para facilitar os testes. O fluxo de
/// autenticação começa em `/auth`.
class AppRouter {
  AppRouter({this.authRepository});

  /// Quando não informado, as páginas resolvem o repositório pelo injetor.
  final AuthRepository? authRepository;

  GoRouter createRouter() {
    return GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          name: AppRoutes.homeName,
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: AppRoutes.authEmail,
          name: AppRoutes.authEmailName,
          builder: (context, state) =>
              AuthEmailPage(repository: authRepository),
        ),
        GoRoute(
          path: AppRoutes.authCode,
          name: AppRoutes.authCodeName,
          redirect: (context, state) {
            final email = state.extra;
            if (email is! String || email.isEmpty) {
              return AppRoutes.authEmail;
            }
            return null;
          },
          builder: (context, state) => AuthCodePage(
            email: state.extra! as String,
            repository: authRepository,
          ),
        ),
      ],
    );
  }
}
