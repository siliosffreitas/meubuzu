import 'package:flutter/services.dart';

import '../../domain/contracts/contracts.dart';
import '../../domain/models/route.dart';
import '../../domain/models/user_coordinates.dart';
import '../utils/csv_catalog.dart';

/// Contrato de consulta do itinerário geográfico de uma linha.
abstract interface class RouteService implements Service {
  /// Retorna o traçado da linha [lineCode] (`sgLinha`).
  ///
  /// Retorna `null` quando a linha não possui traçado cadastrado.
  Future<Route?> findRoute(String lineCode);
}

/// Implementação que lê o traçado de `assets/routes/<sgLinha>.csv`.
///
/// Cada arquivo contém uma coordenada por linha no formato
/// `latitude,longitude`, na ordem do itinerário.
class AssetRouteService implements RouteService {
  AssetRouteService({
    AssetBundle? bundle,
    this.assetDirectory = 'assets/routes',
  }) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String assetDirectory;

  final Map<String, Future<Route?>> _routes = {};

  @override
  Future<Route?> findRoute(String lineCode) {
    final normalized = lineCode.trim();
    if (normalized.isEmpty) {
      return Future<Route?>.value();
    }

    // Guarda o próprio future para evitar leituras duplicadas do asset.
    return _routes[normalized] ??= _loadRoute(normalized);
  }

  Future<Route?> _loadRoute(String lineCode) async {
    final String content;
    try {
      content = await _bundle.loadString(_assetPathFor(lineCode));
    } catch (_) {
      // Linhas sem traçado cadastrado simplesmente não possuem asset.
      return null;
    }

    final positions = <UserCoordinates>[];
    for (final row in parseCsvRows(content)) {
      if (row.length < 2 || row.every((value) => value.trim().isEmpty)) {
        continue;
      }

      final latitude = double.tryParse(row[0].trim());
      final longitude = double.tryParse(row[1].trim());
      if (latitude == null || longitude == null) {
        continue;
      }

      positions.add(UserCoordinates(latitude: latitude, longitude: longitude));
    }

    if (positions.isEmpty) {
      return null;
    }

    return Route(positions: List<UserCoordinates>.unmodifiable(positions));
  }

  String _assetPathFor(String lineCode) {
    final directory = assetDirectory.replaceFirst(RegExp(r'/+$'), '');
    return '$directory/$lineCode.csv';
  }
}
