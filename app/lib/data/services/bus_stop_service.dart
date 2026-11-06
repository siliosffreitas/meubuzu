import 'package:flutter/services.dart';

import '../../domain/contracts/contracts.dart';
import '../../domain/models/bus_stop.dart';
import '../../domain/models/user_coordinates.dart';
import '../utils/csv_catalog.dart';
import '../utils/search_normalizer.dart';

/// Raio padrão usado para considerar uma parada próxima do usuário.
const double nearbyBusStopsRadiusInMeters = 500;

/// Contrato de consulta às paradas de ônibus disponíveis no app.
abstract interface class BusStopService implements Service {
  /// Retorna as paradas a até [maxDistanceInMeters] de [position].
  Future<List<BusStop>> findNearby(
    UserCoordinates position, {
    double maxDistanceInMeters = nearbyBusStopsRadiusInMeters,
  });

  /// Busca paradas por código, denominação ou endereço no catálogo.
  Future<List<BusStop>> search(String query);
}

/// Implementação que lê as paradas do catálogo local em CSV.
class AssetBusStopService implements BusStopService {
  AssetBusStopService({
    AssetBundle? bundle,
    this.assetPath = 'assets/paradas.csv',
  }) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String assetPath;

  Future<List<BusStop>>? _stops;

  @override
  Future<List<BusStop>> findNearby(
    UserCoordinates position, {
    double maxDistanceInMeters = nearbyBusStopsRadiusInMeters,
  }) async {
    final stops = await (_stops ??= _loadStops());
    return stops
        .where(
          (stop) => stop.distanceInMetersTo(position) <= maxDistanceInMeters,
        )
        .toList(growable: false);
  }

  @override
  Future<List<BusStop>> search(String query) async {
    final stops = await (_stops ??= _loadStops());
    final normalizedQuery = normalizeSearchText(query);
    if (normalizedQuery.isEmpty) {
      return const [];
    }
    return stops
        .where(
          (stop) =>
              normalizeSearchText(stop.code).contains(normalizedQuery) ||
              normalizeSearchText(stop.name).contains(normalizedQuery) ||
              normalizeSearchText(stop.address).contains(normalizedQuery),
        )
        .toList(growable: false);
  }

  Future<List<BusStop>> _loadStops() async {
    final content = await _bundle.loadString(assetPath);
    return List<BusStop>.unmodifiable(_parseStops(content));
  }

  List<BusStop> _parseStops(String content) {
    final rows = parseCsvRows(content);
    if (rows.isEmpty) {
      return const [];
    }

    final header = rows.first
        .map((column) => column.trim().toLowerCase())
        .toList(growable: false);
    final idIndex = columnIndex(header, 'id', assetPath);
    final codeIndex = columnIndex(header, 'codigo', assetPath);
    final nameIndex = columnIndex(header, 'denominacao', assetPath);
    final addressIndex = columnIndex(header, 'endereco', assetPath);
    final latitudeIndex = columnIndex(header, 'lat', assetPath);
    final longitudeIndex = columnIndex(header, 'long', assetPath);
    final requiredColumns = <int>[
      idIndex,
      codeIndex,
      nameIndex,
      addressIndex,
      latitudeIndex,
      longitudeIndex,
    ];

    final stops = <BusStop>[];
    for (final row in rows.skip(1)) {
      if (requiredColumns.any((index) => index >= row.length)) {
        continue;
      }
      if (row.every((value) => value.trim().isEmpty)) {
        continue;
      }

      final latitude = double.tryParse(row[latitudeIndex].trim());
      final longitude = double.tryParse(row[longitudeIndex].trim());
      if (latitude == null || longitude == null) {
        continue;
      }

      stops.add(
        BusStop(
          id: row[idIndex].trim(),
          code: row[codeIndex].trim(),
          name: row[nameIndex].trim(),
          address: row[addressIndex].trim(),
          latitude: latitude,
          longitude: longitude,
        ),
      );
    }

    return stops;
  }
}
