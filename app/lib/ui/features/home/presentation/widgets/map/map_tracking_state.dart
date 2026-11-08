import '../../../../../../domain/models/tracked_line.dart';

/// Estado das linhas acompanhadas exibidas no mapa.
///
/// Cada estado concreto representa uma situação distinta da tela e indica à
/// view qual conteúdo exibir para o usuário.
abstract class MapTrackingState {
  const MapTrackingState();

  /// Linhas acompanhadas e seus respectivos traçados.
  List<TrackedLine> get trackedLines => const [];

  /// Indica que o traçado de uma linha está sendo carregado.
  bool get isLoading => false;

  /// Mensagem de erro a ser exibida, quando houver.
  String? get errorMessage => null;

  /// Indica se há ao menos um traçado pronto para desenhar no mapa.
  bool get hasRoutes => trackedLines.any(
    (tracked) => tracked.route?.positions.isNotEmpty ?? false,
  );
}

/// Nenhuma linha está sendo acompanhada.
class MapTrackingIdle extends MapTrackingState {
  const MapTrackingIdle();
}

/// O traçado de uma linha está sendo carregado.
class MapTrackingLoading extends MapTrackingState {
  const MapTrackingLoading({this.trackedLines = const []});

  @override
  final List<TrackedLine> trackedLines;

  @override
  bool get isLoading => true;
}

/// Existem linhas acompanhadas com traçados prontos para o mapa.
class MapTrackingReady extends MapTrackingState {
  const MapTrackingReady(this.trackedLines);

  @override
  final List<TrackedLine> trackedLines;
}

/// Não foi possível carregar ou atualizar o traçado das linhas.
class MapTrackingError extends MapTrackingState {
  const MapTrackingError({
    required this.errorMessage,
    this.trackedLines = const [],
  });

  @override
  final String errorMessage;

  @override
  final List<TrackedLine> trackedLines;
}
