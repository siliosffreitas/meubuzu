import 'package:flutter/services.dart';

import '../../domain/contracts/contracts.dart';
import '../../domain/models/line.dart';
import '../utils/csv_catalog.dart';
import '../utils/search_normalizer.dart';

/// Contrato de busca de linhas no catálogo local.
abstract interface class LineSearchService implements Service {
  /// Busca linhas por código de embarque, nome, origem ou destino.
  Future<List<Line>> search(String query);

  /// Busca linhas pelos [codes] informados, preservando a ordem recebida.
  Future<List<Line>> findByCodes(Iterable<String> codes);
}

/// Implementação que lê as linhas do catálogo local em CSV.
class AssetLineSearchService implements LineSearchService {
  AssetLineSearchService({
    AssetBundle? bundle,
    this.assetPath = 'assets/lines.csv',
  }) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String assetPath;

  Future<List<Line>>? _lines;
  Future<Map<String, Line>>? _linesByCode;

  @override
  Future<List<Line>> search(String query) async {
    final lines = await (_lines ??= _loadLines());
    final normalizedQuery = normalizeSearchText(query);
    if (normalizedQuery.isEmpty) {
      return const [];
    }
    return lines
        .where(
          (line) =>
              normalizeSearchText(line.boardingCode).contains(normalizedQuery) ||
              normalizeSearchText(line.name).contains(normalizedQuery) ||
              normalizeSearchText(line.origin).contains(normalizedQuery) ||
              normalizeSearchText(line.destination).contains(normalizedQuery),
        )
        .toList(growable: false);
  }

  @override
  Future<List<Line>> findByCodes(Iterable<String> codes) async {
    if (codes.isEmpty) {
      return const [];
    }

    final index = await (_linesByCode ??= _loadLinesByCode());
    final result = <Line>[];
    final seen = <String>{};

    for (final code in codes) {
      final normalized = code.trim();
      if (normalized.isEmpty || !seen.add(normalized)) {
        continue;
      }
      final line = index[normalized];
      if (line != null) {
        result.add(line);
      }
    }
    return result;
  }

  /// Indexa as linhas exclusivamente pelo `sgLinha`, identidade pública.
  Future<Map<String, Line>> _loadLinesByCode() async {
    final lines = await (_lines ??= _loadLines());
    return {for (final line in lines) line.publicCode: line};
  }

  Future<List<Line>> _loadLines() async {
    final content = await _bundle.loadString(assetPath);
    final rows = parseCsvRows(content);
    if (rows.isEmpty) {
      return const [];
    }

    final header = rows.first
        .map((column) => column.trim().toLowerCase())
        .toList(growable: false);
    final nameIndex = columnIndex(header, 'nomelinha', assetPath);
    final originIndex = columnIndex(header, 'getorigemida', assetPath);
    final destinationIndex = columnIndex(header, 'destinoida', assetPath);
    final boardingIndex = columnIndex(header, 'sglinha', assetPath);

    final lines = <Line>[];
    for (final row in rows.skip(1)) {
      if (row.length <= nameIndex ||
          row.length <= boardingIndex ||
          row.every((value) => value.trim().isEmpty)) {
        continue;
      }

      final boardingCode = row[boardingIndex].trim();
      if (boardingCode.isEmpty) {
        continue;
      }

      lines.add(
        Line(
          name: row[nameIndex].trim(),
          origin: originIndex < row.length ? row[originIndex].trim() : '',
          destination: destinationIndex < row.length
              ? row[destinationIndex].trim()
              : '',
          boardingCode: boardingCode,
        ),
      );
    }

    return lines;
  }
}
