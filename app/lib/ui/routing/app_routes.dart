/// Caminhos e nomes das rotas do aplicativo.
abstract final class AppRoutes {
  /// Home com as abas Mapa, Favoritos e Conta.
  static const home = '/';
  static const homeName = 'home';

  /// Primeira etapa da autenticação (e-mail).
  static const authEmail = '/auth';
  static const authEmailName = 'auth';

  /// Segunda etapa da autenticação (código). Recebe o e-mail por `extra`.
  static const authCode = '/auth/code';
  static const authCodeName = 'authCode';
}
