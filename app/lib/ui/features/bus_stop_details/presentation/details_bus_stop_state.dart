import '../../../../domain/models/bus_stop.dart';
import '../../../../domain/models/line.dart';

/// Estado da tela de detalhes da parada.
///
/// Cada estado concreto representa uma situação distinta da tela e indica à
/// view qual conteúdo exibir para o usuário.
sealed class DetailsBusStopState {
  const DetailsBusStopState();

  /// Parada exibida no cabeçalho, quando já conhecida.
  BusStop? get busStop => null;

  /// Linhas que passam pela parada.
  List<Line> get lines => const [];
}

/// A tela ainda não iniciou o carregamento da parada.
class DetailsBusStopIdle extends DetailsBusStopState {
  const DetailsBusStopIdle();
}

/// A parada e suas linhas estão sendo carregadas.
class DetailsBusStopLoading extends DetailsBusStopState {
  const DetailsBusStopLoading();
}

/// A parada e as linhas que passam por ela foram carregadas.
class DetailsBusStopReady extends DetailsBusStopState {
  const DetailsBusStopReady({required this.busStop, required this.lines});

  @override
  final BusStop busStop;

  @override
  final List<Line> lines;
}

/// A parada informada não existe no catálogo.
class DetailsBusStopNotFound extends DetailsBusStopState {
  const DetailsBusStopNotFound();
}

/// Não foi possível carregar os dados da parada.
class DetailsBusStopError extends DetailsBusStopState {
  const DetailsBusStopError();
}
