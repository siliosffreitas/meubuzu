import '../../domain/repositories/place_search_repository.dart';
import '../models/place_suggestion.dart';

/// Implementação temporária com dados de exemplo, útil para previews e testes
/// manuais quando o catálogo local não está disponível.
class FakePlaceSearchRepository implements PlaceSearchRepository {
  const FakePlaceSearchRepository({
    this.latency = const Duration(milliseconds: 420),
  });

  final Duration latency;

  static const _catalog = <PlaceSuggestion>[
    PlaceSuggestion(
      id: '875A-10',
      code: '875A-10',
      type: PlaceSuggestionType.line,
      title: 'Perdizes ↔ Terminal Lapa',
      subtitle: 'Perdizes → Terminal Lapa',
      latitude: -23.537,
      longitude: -46.676,
    ),
    PlaceSuggestion(
      id: '8000-1',
      code: '8000-1',
      type: PlaceSuggestionType.line,
      title: 'Terminal Lapa ↔ Praça Ramos',
      subtitle: 'Terminal Lapa → Praça Ramos',
      latitude: -23.522,
      longitude: -46.701,
    ),
    PlaceSuggestion(
      id: '918P-10',
      code: '918P-10',
      type: PlaceSuggestionType.line,
      title: 'Vila Nova Cachoeirinha ↔ Lapa',
      subtitle: 'Vila Nova Cachoeirinha → Lapa',
      latitude: -23.506,
      longitude: -46.674,
    ),
    PlaceSuggestion(
      id: '101',
      code: '101',
      type: PlaceSuggestionType.line,
      title: 'Terminal Pinheiros ↔ Centro',
      subtitle: 'Terminal Pinheiros → Centro',
      latitude: -23.567,
      longitude: -46.694,
    ),
    PlaceSuggestion(
      id: 'parada-se',
      code: 'SE',
      type: PlaceSuggestionType.stop,
      title: 'Praça da Sé',
      subtitle: 'Parada · Sé',
      latitude: -23.5505,
      longitude: -46.6333,
    ),
    PlaceSuggestion(
      id: 'parada-luz',
      code: 'LUZ',
      type: PlaceSuggestionType.stop,
      title: 'Estação da Luz',
      subtitle: 'Parada · Luz',
      latitude: -23.534,
      longitude: -46.635,
    ),
    PlaceSuggestion(
      id: 'parada-lapa',
      code: 'LAPA',
      type: PlaceSuggestionType.stop,
      title: 'Terminal Lapa',
      subtitle: 'Parada · Lapa',
      latitude: -23.5226,
      longitude: -46.703,
    ),
    PlaceSuggestion(
      id: 'parada-masp',
      code: 'MASP',
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
