import '../../../domain/models/line.dart';

/// Texto de sentido exibido no subtítulo da linha.
extension LineDirectionLabel on Line {
  /// Rótulo do sentido, no mesmo formato usado nos detalhes da linha.
  String get directionLabel => lineDirectionLabel(this);
}

/// Calcula o rótulo de sentido de uma [line].
///
/// Retorna [Line.origin] quando não há destino, `Circular • <origem>` quando
/// origem e destino são iguais, ou `Sentido <destino>` nos demais casos.
String lineDirectionLabel(Line line) {
  final origin = line.origin.trim();
  final destination = line.destination.trim();
  if (destination.isEmpty) {
    return origin;
  }
  if (origin.isNotEmpty && origin == destination) {
    return 'Circular • $origin';
  }
  return 'Sentido $destination';
}
