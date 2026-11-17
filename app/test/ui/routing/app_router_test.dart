import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/ui/routing/app_router.dart';
import 'package:meubuzu/ui/routing/app_routes.dart';

void main() {
  group('authRedirect', () {
    test('sem sessão vai para a autenticação', () {
      expect(
        authRedirect(
          isAuthenticated: false,
          hasSelectedCity: false,
          location: AppRoutes.home,
          hasEmail: false,
        ),
        AppRoutes.authEmail,
      );
      expect(
        authRedirect(
          isAuthenticated: false,
          hasSelectedCity: false,
          location: AppRoutes.mapSearch,
          hasEmail: false,
        ),
        AppRoutes.authEmail,
      );
    });

    test('sem sessão permanece nas rotas de autenticação', () {
      expect(
        authRedirect(
          isAuthenticated: false,
          hasSelectedCity: false,
          location: AppRoutes.authEmail,
          hasEmail: false,
        ),
        isNull,
      );
      expect(
        authRedirect(
          isAuthenticated: false,
          hasSelectedCity: false,
          location: AppRoutes.authCode,
          hasEmail: true,
        ),
        isNull,
      );
    });

    test('rota de código sem e-mail volta para a tela de e-mail', () {
      expect(
        authRedirect(
          isAuthenticated: false,
          hasSelectedCity: false,
          location: AppRoutes.authCode,
          hasEmail: false,
        ),
        AppRoutes.authEmail,
      );
    });

    test('com sessão e cidade vai para a Home', () {
      expect(
        authRedirect(
          isAuthenticated: true,
          hasSelectedCity: true,
          location: AppRoutes.authEmail,
          hasEmail: false,
        ),
        AppRoutes.home,
      );
      expect(
        authRedirect(
          isAuthenticated: true,
          hasSelectedCity: true,
          location: AppRoutes.authCode,
          hasEmail: true,
        ),
        AppRoutes.home,
      );
    });

    test('com sessão e cidade mantém rotas internas', () {
      expect(
        authRedirect(
          isAuthenticated: true,
          hasSelectedCity: true,
          location: AppRoutes.mapSearch,
          hasEmail: false,
        ),
        isNull,
      );
      expect(
        authRedirect(
          isAuthenticated: true,
          hasSelectedCity: true,
          location: AppRoutes.home,
          hasEmail: false,
        ),
        isNull,
      );
    });

    test('com sessão sem cidade vai para a seleção de cidade', () {
      expect(
        authRedirect(
          isAuthenticated: true,
          hasSelectedCity: false,
          location: AppRoutes.authEmail,
          hasEmail: false,
        ),
        AppRoutes.selectCity,
      );
      expect(
        authRedirect(
          isAuthenticated: true,
          hasSelectedCity: false,
          location: AppRoutes.authCode,
          hasEmail: true,
        ),
        AppRoutes.selectCity,
      );
      expect(
        authRedirect(
          isAuthenticated: true,
          hasSelectedCity: false,
          location: AppRoutes.home,
          hasEmail: false,
        ),
        AppRoutes.selectCity,
      );
    });

    test('com sessão sem cidade permanece na seleção de cidade', () {
      expect(
        authRedirect(
          isAuthenticated: true,
          hasSelectedCity: false,
          location: AppRoutes.selectCity,
          hasEmail: false,
        ),
        isNull,
      );
    });

    test('com sessão e cidade não volta para a seleção de cidade', () {
      expect(
        authRedirect(
          isAuthenticated: true,
          hasSelectedCity: true,
          location: AppRoutes.selectCity,
          hasEmail: false,
        ),
        isNull,
      );
    });
  });
}
