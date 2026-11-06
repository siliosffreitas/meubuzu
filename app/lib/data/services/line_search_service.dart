import 'package:flutter/services.dart';

import '../../domain/contracts/contracts.dart';
import '../../domain/models/line.dart';
import '../utils/csv_catalog.dart';
import '../utils/search_normalizer.dart';

/// Contrato de busca de linhas no catálogo local.
abstract interface class LineSearchService implements Service {
  /// Busca linhas por código ou nome.
  Future<List<Line>> search(String query);
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
              normalizeSearchText(line.id).contains(normalizedQuery) ||
              normalizeSearchText(line.name).contains(normalizedQuery) ||
              (line.boardingCode != null &&
                  normalizeSearchText(line.boardingCode!)
                      .contains(normalizedQuery)),
        )
        .toList(growable: false);
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
    final idIndex = columnIndex(header, 'codigolinha', assetPath);
    final nameIndex = columnIndex(header, 'nomelinha', assetPath);
    final originIndex = columnIndex(header, 'getorigemida', assetPath);
    final destinationIndex = columnIndex(header, 'destinoida', assetPath);
    final boardingIndex = columnIndex(header, 'sglinha', assetPath);

    final lines = <Line>[];
    for (final row in rows.skip(1)) {
      if (row.length <= idIndex || row.length <= nameIndex) {
        continue;
      }
      if (row.every((value) => value.trim().isEmpty)) {
        continue;
      }

      lines.add(
        Line(
          id: row[idIndex].trim(),
          name: row[nameIndex].trim(),
          origin: originIndex < row.length ? row[originIndex].trim() : '',
          destination: destinationIndex < row.length
              ? row[destinationIndex].trim()
              : '',
          boardingCode: boardingIndex < row.length
              ? row[boardingIndex].trim()
              : null,
        ),
      );
    }

    return lines;
  }
}
