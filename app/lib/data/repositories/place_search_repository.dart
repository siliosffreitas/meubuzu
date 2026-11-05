import '../../domain/repositories/place_search_repository.dart';
import '../models/place_suggestion.dart';

/// Implementação temporária enquanto o backend não expõe a busca.
class FakePlaceSearchRepository implements PlaceSearchRepository {
  const FakePlaceSearchRepository({
    this.latency = const Duration(milliseconds: 420),
  });

  final Duration latency;

  static const _catalog = <PlaceSuggestion>[
    PlaceSuggestion(
      id: '875A-10',
      type: PlaceSuggestionType.line,
      title: '875A-10',
      subtitle: 'Perdizes ↔ Terminal Lapa',
      latitude: -23.537,
      longitude: -46.676,
    ),
    PlaceSuggestion(
      id: '8000-1',
      type: PlaceSuggestionType.line,
      title: '8000-1',
      subtitle: 'Terminal Lapa ↔ Praça Ramos',
      latitude: -23.522,
      longitude: -46.701,
    ),
    PlaceSuggestion(
      id: '918P-10',
      type: PlaceSuggestionType.line,
      title: '918P-10',
      subtitle: 'Vila Nova Cachoeirinha ↔ Lapa',
      latitude: -23.506,
      longitude: -46.674,
    ),
    PlaceSuggestion(
      id: '101',
      type: PlaceSuggestionType.line,
      title: '101',
      subtitle: 'Terminal Pinheiros ↔ Centro',
      latitude: -23.567,
      longitude: -46.694,
    ),
    PlaceSuggestion(
      id: 'parada-se',
      type: PlaceSuggestionType.stop,
      title: 'Praça da Sé',
      subtitle: 'Parada · Sé',
      latitude: -23.5505,
      longitude: -46.6333,
    ),
    PlaceSuggestion(
      id: 'parada-luz',
      type: PlaceSuggestionType.stop,
      title: 'Estação da Luz',
      subtitle: 'Parada · Luz',
      latitude: -23.534,
      longitude: -46.635,
    ),
    PlaceSuggestion(
      id: 'parada-lapa',
      type: PlaceSuggestionType.stop,
      title: 'Terminal Lapa',
      subtitle: 'Parada · Lapa',
      latitude: -23.5226,
      longitude: -46.703,
    ),
    PlaceSuggestion(
      id: 'parada-masp',
      type: PlaceSuggestionType.stop,
      title: 'MASP',
      subtitle: 'Parada · Avenida Paulista',
      latitude: -23.5614,
      longitude: -46.6559,
    ),
  ];

  @override
  Future<List<PlaceSuggestion>> search(String query) async {
    await Future<void>.delayed(latency);
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    return _catalog.where((suggestion) => suggestion.matches(trimmed)).toList();
  }

  @override
  void dispose() {}
}
