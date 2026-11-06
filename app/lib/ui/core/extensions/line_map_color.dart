import 'package:flutter/material.dart';

import '../../../data/models/line.dart';

/// Cor de identificação visual das linhas.
extension LineMapColor on Line {
  /// Cor com que a linha aparece no mapa e nos destaques da busca.
  ///
  /// É derivada do [boardingCode] (com fallback para [id]) para que a mesma
  /// linha mantenha sempre a mesma cor entre execuções.
  Color get mapColor {
    final code = boardingCode?.trim();
    return lineMapColor(code == null || code.isEmpty ? id : code);
  }
}

/// Calcula a cor de uma linha a partir do seu código de embarque (`sgLinha`).
///
/// A mesma entrada sempre gera a mesma cor. A matiz é distribuída pelo hash do
/// código e a saturação/luminosidade variam em faixas fixas, garantindo cores
/// distintas e contraste suficiente para o texto branco sobre o fundo.
Color lineMapColor(String code) {
  final hash = _stableHash(code.trim().toLowerCase());
  final hue = (hash % 3600) / 10;
  final saturation = 0.48 + ((hash >> 12) % 18) / 100;
  final lightness = 0.26 + ((hash >> 20) % 4) / 100;
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
