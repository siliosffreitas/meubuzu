import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../di/dependencies.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/place_search_repository.dart';
import '../features/auth/presentation/auth_code/auth_code_page.dart';
import '../features/auth/presentation/auth_email/auth_email_page.dart';
import '../features/bus_stop_details/presentation/details_bus_stop_page.dart';
import '../features/city_selection/presentation/select_city_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/home/presentation/widgets/map/map_search_arguments.dart';
import '../features/home/presentation/widgets/map/map_search_page.dart';
import '../features/line_details/presentation/details_line_page.dart';
import 'app_routes.dart';

/// Configura as rotas do aplicativo com GoRouter.
///
/// Sem sessão, qualquer rota leva para a autenticação por e-mail. Com sessão,
/// as rotas de autenticação levam para a Home.
class AppRouter {
  AppRouter({this.authRepository});

  /// Quando não informado, o repositório é resolvido pelo injetor.
  final AuthRepository? authRepository;

  GoRouter createRouter() {
    final repository =
        authRepository ?? injector.getRepository<AuthRepository>();

    return GoRouter(
      initialLocation: AppRoutes.authEmail,
      refreshListenable: repository,
      redirect: (context, state) {
        final email = state.extra;
        return authRedirect(
          isAuthenticated: repository.isAuthenticated,
          hasSelectedCity: repository.hasSelectedCity,
          location: state.matchedLocation,
          hasEmail: email is String && email.isNotEmpty,
        );
      },
      routes: [
        GoRoute(
          path: AppRoutes.home,
          name: AppRoutes.homeName,
          builder: (context, state) {
            final tabRequest = state.extra is int ? state.extra! as int : null;
            return HomePage(
              key: tabRequest == null
                  ? null
                  : ValueKey<String>('home-tab-request-$tabRequest'),
              initialTabIndex: tabRequest ?? AppRoutes.homeTabMap,
            );
          },
        ),
        GoRoute(
          path: AppRoutes.mapSearch,
          name: AppRoutes.mapSearchName,
          builder: (context, state) {
            final extra = state.extra;
            if (extra is MapSearchPageArguments) {
              return MapSearchPage(
                repository: extra.repository,
                trackingRepository: extra.trackingRepository,
                favoritesRepository: extra.favoritesRepository,
                activeSuggestionId: extra.activeSuggestionId,
              );
            }
            return MapSearchPage(
              repository: extra is PlaceSearchRepository ? extra : null,
            );
          },
        ),
        GoRoute(
          path: AppRoutes.detailsLine,
          name: AppRoutes.detailsLineName,
          builder: (context, state) =>
              DetailsLinePage(lineCode: state.pathParameters['code'] ?? ''),
        ),
        GoRoute(
          path: AppRoutes.detailsBusStop,
          name: AppRoutes.detailsBusStopName,
          builder: (context, state) => DetailsBusStopPage(
            busStopCode: state.pathParameters['code'] ?? '',
          ),
        ),
        GoRoute(
          path: AppRoutes.selectCity,
          name: AppRoutes.selectCityName,
          builder: (context, state) => SelectCityPage(
            isChangeMode: state.uri.queryParameters['change'] == '1',
          ),
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
          builder: (context, state) => AuthCodePage(
            email: state.extra! as String,
            repository: authRepository,
          ),
        ),
      ],
    );
  }
}

/// Regra de redirecionamento da autenticação e da cidade, isolada para testes.
@visibleForTesting
String? authRedirect({
  required bool isAuthenticated,
  required bool hasSelectedCity,
  required String location,
  required bool hasEmail,
}) {
  final isAuthRoute =
      location == AppRoutes.authEmail || location == AppRoutes.authCode;

  if (!isAuthenticated && !isAuthRoute) {
    return AppRoutes.authEmail;
  }
  if (isAuthenticated && isAuthRoute) {
    return hasSelectedCity ? AppRoutes.home : AppRoutes.selectCity;
  }
  if (isAuthenticated && !hasSelectedCity && location != AppRoutes.selectCity) {
    return AppRoutes.selectCity;
  }
  if (location == AppRoutes.authCode && !hasEmail) {
    return AppRoutes.authEmail;
  }
  return null;
}
