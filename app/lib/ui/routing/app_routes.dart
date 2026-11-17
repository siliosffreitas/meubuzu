/// Caminhos e nomes das rotas do aplicativo.
abstract final class AppRoutes {
  /// Home com as abas Mapa, Favoritos e Conta.
  static const home = '/';
  static const homeName = 'home';

  /// Busca dedicada de linhas e paradas. Retorna a sugestão escolhida por
  /// `pop(result)`.
  static const mapSearch = '/search';
  static const mapSearchName = 'mapSearch';

  /// Detalhes da linha e suas paradas. Recebe o código da linha em `code`.
  static const detailsLine = '/line/:code';
  static const detailsLineName = 'detailsLine';

  /// Detalhes da parada e as linhas que passam por ela. Recebe o código da
  /// parada em `code`.
  static const detailsBusStop = '/stop/:code';
  static const detailsBusStopName = 'detailsBusStop';

  /// Primeira etapa da autenticação (e-mail).
  static const authEmail = '/auth';
  static const authEmailName = 'auth';

  /// Segunda etapa da autenticação (código). Recebe o e-mail por `extra`.
  static const authCode = '/auth/code';
  static const authCodeName = 'authCode';

  /// Seleção de cidade. É a primeira tela após o login e também é aberta pela
  /// aba Conta com `?change=1`.
  static const selectCity = '/select-city';
  static const selectCityName = 'selectCity';
}
