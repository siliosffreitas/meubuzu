import 'package:meubuzu/domain/models/tracked_line.dart';

import '../contracts/contracts.dart';

abstract interface class TrackingRepository implements Repository {
  /// Emite as linhas acompanhadas e seus respectivos traçados.
  ///
  /// Novos ouvintes recebem imediatamente o estado atual.
  Stream<List<TrackedLine>> get trackingRoutes;

  /// Inicia o acompanhamento da linha [lineCode] (`sgLinha`).
  Future<void> startTracking(String lineCode);

  /// Encerra o acompanhamento da linha [lineCode] (`sgLinha`).
  Future<void> stopTracking(String lineCode);
}
