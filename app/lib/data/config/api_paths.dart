/// Caminhos da API que dependem da cidade explícita.
///
/// Todo endpoint de catálogo ou rastreamento deve ser montado por aqui para que
/// nenhuma chamada aconteça sem `{citySlug}`.
abstract final class ApiPaths {
  static String city(String citySlug, String path) {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return '/v1/cities/$citySlug/$normalized';
  }
}
