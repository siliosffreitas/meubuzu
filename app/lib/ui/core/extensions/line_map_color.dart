import 'package:flutter/material.dart';

import '../../../domain/models/line.dart';

/// Cor de identificação visual das linhas.
extension LineMapColor on Line {
  /// Cor com que a linha aparece no mapa e nos destaques da busca.
  ///
  /// É derivada do [boardingCode] e também do [name], para que a mesma linha
  /// mantenha sempre a mesma cor entre execuções e linhas diferentes não
  /// fiquem com cores iguais.
  Color get mapColor => lineMapColor(publicCode, name);
}

/// Calcula a cor de uma linha a partir do `sgLinha` e do nome da linha.
///
/// A mesma combinação de código e nome sempre gera a mesma cor. A matiz é
/// distribuída pelo hash dos dois campos, enquanto saturação e luminosidade
/// variam em faixas fixas, garantindo cores distintas e contraste suficiente
/// para o texto branco sobre o fundo.
Color lineMapColor(String code, String name) {
  final key = '${code.trim().toLowerCase()}|${name.trim().toLowerCase()}';
  final hash = _stableHash(key);
  final hue = (hash % 3600) / 10;
  final saturation = 0.45 + ((hash >> 12) % 26) / 100;
  final lightness = 0.25 + ((hash >> 20) % 6) / 100;
  return HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();
}

/// Hash FNV-1a de 32 bits com mistura final, estável entre execuções.
int _stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  hash ^= hash >> 16;
  hash = (hash * 0x7feb352d) & 0xFFFFFFFF;
  hash ^= hash >> 15;
  hash = (hash * 0x846ca68b) & 0xFFFFFFFF;
  hash ^= hash >> 16;
  return hash;
}
