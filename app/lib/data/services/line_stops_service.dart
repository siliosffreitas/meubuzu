import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/contracts/contracts.dart';

/// Contrato de consulta das paradas atendidas por uma linha e vice-versa.
abstract interface class LineStopsService implements Service {
  /// Retorna os códigos das paradas atendidas pela linha [lineCode] (`sgLinha`).
  Future<List<String>> findStopCodesForLine(String lineCode);

  /// Retorna os códigos das linhas que passam pela parada [stopCode].
  Future<List<String>> findLineCodesForStop(String stopCode);
}

/// Implementação que lê o mapa `sgLinha -> códigos de paradas` do asset JSON.
class AssetLineStopsService implements LineStopsService {
  AssetLineStopsService({
    AssetBundle? bundle,
    this.assetPath = 'assets/lines_paradas.json',
  }) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String assetPath;

  Future<Map<String, List<String>>>? _lines;
  Future<Map<String, List<String>>>? _stopsToLines;

  @override
  Future<List<String>> findStopCodesForLine(String lineCode) async {
    final normalized = lineCode.trim();
    if (normalized.isEmpty) {
      return const [];
    }

    final lines = await (_lines ??= _loadLines());
    return lines[normalized] ?? const [];
  }

  @override
  Future<List<String>> findLineCodesForStop(String stopCode) async {
    final normalized = stopCode.trim();
    if (normalized.isEmpty) {
      return const [];
    }

    final stopsToLines = await (_stopsToLines ??= _loadStopsToLines());
    return stopsToLines[normalized] ?? const [];
  }

  /// Monta o índice reverso `parada -> linhas` a partir do mesmo asset.
  Future<Map<String, List<String>>> _loadStopsToLines() async {
    final lines = await (_lines ??= _loadLines());
    final stopsToLines = <String, Set<String>>{};

    lines.forEach((lineCode, stopCodes) {
      for (final stopCode in stopCodes) {
        (stopsToLines[stopCode] ??= <String>{}).add(lineCode);
      }
    });

    return {
      for (final entry in stopsToLines.entries)
        entry.key: List<String>.unmodifiable(entry.value),
    };
  }

  Future<Map<String, List<String>>> _loadLines() async {
    final content = await _bundle.loadString(assetPath);
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      return const {};
    }

    final result = <String, List<String>>{};
    decoded.forEach((key, value) {
      if (value is! String) {
        return;
      }
      result[key.trim()] = value
          .split(',')
          .map((code) => code.trim())
          .where((code) => code.isNotEmpty)
          .toList(growable: false);
    });
    return result;
  }
}
