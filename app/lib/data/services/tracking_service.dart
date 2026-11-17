import '../../domain/contracts/contracts.dart';
import '../../domain/models/bus_position.dart';
import '../../domain/models/line.dart';

/// Contrato de consulta das posições dos ônibus.
///
/// A implementação remota consulta o backend uma única vez com todas as linhas
/// informadas, usando o `sgLinha` de cada linha. Cada [BusPosition] devolvida
/// identifica sua linha em `lineCode`, para que o repositório possa separar o
/// resultado por linha acompanhada.
abstract interface class TrackingService implements Service {
  /// Retorna as posições mais recentes de todas as [lines].
  Future<List<BusPosition>> findPositions(List<Line> lines, {DateTime? at});
}

/// Serviço vazio usado apenas como fallback de widgets sem injetor.
class EmptyTrackingService implements TrackingService {
  const EmptyTrackingService();

  @override
  Future<List<BusPosition>> findPositions(List<Line> lines, {DateTime? at}) async {
    return const <BusPosition>[];
  }
}

/// Remove apenas espaços do `sgLinha`, preservando os zeros à esquerda.
///
/// O contrato de rastreamento usa o código de embarque (por exemplo, `0301`)
/// como parâmetro da API e como identificador da linha nas posições.
String normalizeLineCode(String value) => value.trim();
