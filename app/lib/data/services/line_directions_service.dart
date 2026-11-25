import '../../domain/contracts/contracts.dart';
import '../../domain/models/line_direction.dart';

/// Contrato de consulta dos sentidos/itinerários disponíveis de uma linha.
abstract interface class LineDirectionsService implements Service {
  /// Retorna os sentidos da linha [lineCode] (`sgLinha`).
  ///
  /// Uma linha sem itinerário cadastrado devolve uma lista vazia.
  Future<List<LineDirection>> findDirections(String lineCode);
}

/// Implementação usada apenas quando não há backend disponível.
class EmptyLineDirectionsService implements LineDirectionsService {
  const EmptyLineDirectionsService();

  @override
  Future<List<LineDirection>> findDirections(String lineCode) async {
    return const [];
  }
}
