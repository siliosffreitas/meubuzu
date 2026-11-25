import 'dart:async';

import '../../../../../../domain/contracts/contracts.dart';
import '../../../../../../domain/models/tracked_line.dart';
import '../../../../../../domain/repositories/tracking_repository.dart';
import 'map_tracking_state.dart';

/// Coordena o acompanhamento das linhas exibidas no mapa.
///
/// A view apenas observa [state] e chama as ações; toda a comunicação com o
/// [TrackingRepository] acontece aqui.
class MapTrackingViewModel extends ViewmodelBase {
  MapTrackingViewModel(this._repository) {
    _subscription = _repository.trackingRoutes.listen(
      _handleRoutes,
      onError: _handleError,
    );
  }

  final TrackingRepository _repository;
  late final StreamSubscription<List<TrackedLine>> _subscription;

  MapTrackingState _state = const MapTrackingIdle();
  List<TrackedLine> _trackedLines = const [];
  DateTime? _updatedAt;
  bool _isDisposed = false;

  /// Estado atual das linhas acompanhadas.
  MapTrackingState get state => _state;

  /// Linhas acompanhadas que devem ser desenhadas no mapa.
  List<TrackedLine> get trackedLines => _trackedLines;

  /// Momento da última atualização recebida do repositório.
  DateTime? get updatedAt => _updatedAt;

  /// Indica se há linhas sendo acompanhadas.
  bool get hasTrackedLines => _trackedLines.isNotEmpty;

  /// Quantidade de linhas sendo acompanhadas.
  int get trackedLineCount => _trackedLines.length;

  /// Inicia o acompanhamento da linha [lineCode] (`sgLinha`).
  ///
  /// Retorna `true` quando a linha foi adicionada ao rastreamento.
  Future<bool> startTracking(String lineCode) async {
    final normalized = lineCode.trim();
    if (normalized.isEmpty || _isDisposed) {
      return false;
    }

    if (_trackedLines.isEmpty) {
      _update(const MapTrackingLoading());
    }

    try {
      final tracked = await _repository.startTracking(normalized);
      if (_isDisposed) {
        return false;
      }
      if (tracked == null) {
        _update(
          MapTrackingError(
            trackedLines: _trackedLines,
            errorMessage:
                'Não foi possível carregar a rota da linha $normalized.',
          ),
        );
        return false;
      }
      return true;
    } catch (_) {
      if (!_isDisposed) {
        _update(
          MapTrackingError(
            trackedLines: _trackedLines,
            errorMessage:
                'Não foi possível carregar a rota da linha $normalized.',
          ),
        );
      }
      return false;
    }
  }

  /// Troca o sentido exibido da linha [lineCode] (`sgLinha`).
  ///
  /// Retorna `true` quando o traçado foi atualizado. Em falha, mantém o estado
  /// anterior (inclusive os ônibus já exibidos).
  Future<bool> changeDirection(String lineCode, int direction) async {
    final normalized = lineCode.trim();
    if (normalized.isEmpty || _isDisposed) {
      return false;
    }

    try {
      final updated = await _repository.changeDirection(normalized, direction);
      if (_isDisposed || updated == null) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Encerra o acompanhamento da linha [lineCode] (`sgLinha`).
  Future<void> stopTracking(String lineCode) async {
    if (_isDisposed) {
      return;
    }
    await _repository.stopTracking(lineCode.trim());
  }

  void _handleRoutes(List<TrackedLine> routes) {
    _trackedLines = routes;
    _updatedAt = routes.isEmpty ? null : DateTime.now();
    _update(
      routes.isEmpty ? const MapTrackingIdle() : MapTrackingReady(routes),
    );
  }

  void _handleError(Object error, StackTrace stackTrace) {
    _update(
      MapTrackingError(
        trackedLines: _trackedLines,
        errorMessage: 'Não foi possível atualizar as linhas acompanhadas.',
      ),
    );
  }

  void _update(MapTrackingState state) {
    if (_isDisposed) {
      return;
    }
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _subscription.cancel();
    super.dispose();
  }
}
