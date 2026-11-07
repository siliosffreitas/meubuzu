import '../../../../domain/models/bus_stop.dart';
import '../../../../domain/models/line.dart';

/// Estado da tela de detalhes da linha.
///
/// Cada estado concreto representa uma situação distinta da tela e indica à
/// view qual conteúdo exibir para o usuário.
sealed class DetailsLineState {
  const DetailsLineState();

  /// Linha exibida no cabeçalho, quando já conhecida.
  Line? get line => null;

  /// Paradas da linha, na ordem do itinerário.
  List<BusStop> get stops => const [];
}

/// A tela ainda não iniciou o carregamento da linha.
class DetailsLineIdle extends DetailsLineState {
  const DetailsLineIdle();
}

/// A linha e suas paradas estão sendo carregadas.
class DetailsLineLoading extends DetailsLineState {
  const DetailsLineLoading();
}

/// A linha e suas paradas foram carregadas com sucesso.
class DetailsLineReady extends DetailsLineState {
  const DetailsLineReady({required this.line, required this.stops});

  @override
  final Line line;

  @override
  final List<BusStop> stops;
}

/// A linha foi encontrada, mas não possui paradas cadastradas.
class DetailsLineNoStops extends DetailsLineState {
  const DetailsLineNoStops(this.line);

  @override
  final Line line;
}

/// A linha informada não existe no catálogo.
class DetailsLineNotFound extends DetailsLineState {
  const DetailsLineNotFound();
}

/// Não foi possível carregar os dados da linha.
class DetailsLineError extends DetailsLineState {
  const DetailsLineError();
}
