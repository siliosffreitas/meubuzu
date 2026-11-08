import '../../../../../../domain/repositories/place_search_repository.dart';
import '../../../../../../domain/repositories/tracking_repository.dart';

/// Argumentos aceitos pela rota de busca do mapa.
class MapSearchPageArguments {
  const MapSearchPageArguments({
    this.repository,
    this.trackingRepository,
    this.activeSuggestionId,
  });

  /// Repositório injetado em testes. Quando nulo, a página usa o injetor.
  final PlaceSearchRepository? repository;

  /// Repositório de rastreamento injetado em testes.
  final TrackingRepository? trackingRepository;

  /// Linha atualmente exibida no mapa, marcada como "Acompanhando no mapa".
  final String? activeSuggestionId;
}
