import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Anima a posição exibida dos ônibus entre duas atualizações do rastreamento.
///
/// O mapa reposiciona os marcadores a cada quadro enquanto a animação roda. A
/// primeira posição de um ônibus aparece direto no destino, sem animação.
class TrackingBusAnimator extends ChangeNotifier {
  TrackingBusAnimator({
    required TickerProvider vsync,
    this.duration = const Duration(milliseconds: 300),
  }) : _controller = AnimationController(vsync: vsync, duration: duration) {
    _controller.addListener(notifyListeners);
  }

  /// Duração da transição entre a posição antiga e a nova.
  final Duration duration;

  final AnimationController _controller;

  Map<String, LatLng> _from = const {};
  Map<String, LatLng> _to = const {};

  /// Posições exibidas neste instante, pela chave `linha:ônibus`.
  Map<String, LatLng> get positions {
    if (!_controller.isAnimating) {
      return _to;
    }

    final progress = _controller.value;
    return {
      for (final entry in _to.entries)
        entry.key: _lerp(
          _from[entry.key] ?? entry.value,
          entry.value,
          progress,
        ),
    };
  }

  /// Indica se há uma transição em andamento.
  bool get isAnimating => _controller.isAnimating;

  /// Exibe [targets] diretamente, sem animação.
  void jumpTo(Map<String, LatLng> targets) {
    _controller.stop();
    _from = targets;
    _to = targets;
    notifyListeners();
  }

  /// Anima os ônibus da posição exibida até [targets].
  ///
  /// Se uma nova atualização chegar no meio da animação, a transição começa da
  /// posição interpolada naquele momento. Ônibus que aparecem pela primeira vez
  /// entram direto no destino.
  void animateTo(Map<String, LatLng> targets) {
    final current = positions;

    final hasMovement = targets.entries.any((entry) {
      final previous = current[entry.key];
      return previous != null &&
          (previous.latitude != entry.value.latitude ||
              previous.longitude != entry.value.longitude);
    });

    _from = {
      for (final entry in targets.entries)
        entry.key: current[entry.key] ?? entry.value,
    };
    _to = targets;

    if (!hasMovement) {
      _controller.stop();
      notifyListeners();
      return;
    }

    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  LatLng _lerp(LatLng from, LatLng to, double progress) {
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * progress,
      from.longitude + (to.longitude - from.longitude) * progress,
    );
  }
}
