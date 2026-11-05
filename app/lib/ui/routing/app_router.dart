import 'package:go_router/go_router.dart';

import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/place_search_repository.dart';
import '../features/auth/presentation/auth_code/auth_code_page.dart';
import '../features/auth/presentation/auth_email/auth_email_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/home/presentation/widgets/map/map_search_page.dart';
import 'app_routes.dart';

/// Configura as rotas do aplicativo com GoRouter.
///
/// O app inicia no fluxo de autenticação (`/auth`) e, após confirmar o código,
/// navega para a Home (`/`).
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
          path: AppRoutes.mapSearch,
          name: AppRoutes.mapSearchName,
          builder: (context, state) {
            final extra = state.extra;
            return MapSearchPage(
              repository: extra is PlaceSearchRepository ? extra : null,
            );
          },
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
