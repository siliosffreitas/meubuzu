import '../../../../domain/repositories/auth_repository.dart';

/// Mensagens de erro compartilhadas pelo fluxo de autenticação.
///
/// O texto fica na camada de apresentação; o repositório expõe apenas códigos
/// estáveis da API.
String rateLimitMessage(RateLimitedException error) {
  final retryAfter = error.retryAfter;
  if (retryAfter != null && retryAfter.inSeconds > 0) {
    final seconds = retryAfter.inSeconds;
    final unit = seconds == 1 ? 'segundo' : 'segundos';
    return 'Aguarde $seconds $unit para solicitar um novo código.';
  }
  return 'Muitas solicitações em pouco tempo. Aguarde alguns instantes e '
      'tente novamente.';
}

/// Título exibido quando o código informado não é aceito.
String invalidCodeTitle(String code) {
  return switch (code) {
    'code_expired' => 'Código expirado',
    'code_already_used' => 'Código já utilizado',
    'too_many_attempts' => 'Muitas tentativas',
    _ => 'Código inválido',
  };
}

/// Orientação exibida quando o código informado não é aceito.
String invalidCodeMessage(String code) {
  return switch (code) {
    'code_expired' => 'Este código expirou. Solicite um novo código.',
    'code_already_used' =>
      'Este código já foi utilizado. Solicite outro código.',
    'too_many_attempts' =>
      'Muitas tentativas incorretas. Solicite um novo código.',
    _ =>
      'Confira os 6 dígitos e tente novamente. Se precisar, solicite '
          'outro código.',
  };
}
