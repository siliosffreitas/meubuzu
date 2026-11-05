import 'package:flutter/services.dart';

import '../../domain/contracts/contracts.dart';
import '../models/bus_stop.dart';
import '../models/user_coordinates.dart';

/// Raio padrão usado para considerar uma parada próxima do usuário.
const double nearbyBusStopsRadiusInMeters = 500;

/// Contrato de consulta às paradas de ônibus disponíveis no app.
abstract interface class BusStopService implements Service {
  /// Retorna as paradas a até [maxDistanceInMeters] de [position].
  Future<List<BusStop>> findNearby(
    UserCoordinates position, {
    double maxDistanceInMeters = nearbyBusStopsRadiusInMeters,
  });
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

  Future<List<BusStop>> _loadStops() async {
    final content = await _bundle.loadString(assetPath);
    return List<BusStop>.unmodifiable(_parseStops(content));
  }

  List<BusStop> _parseStops(String content) {
    final rows = _parseRows(content);
    if (rows.isEmpty) {
      return const [];
    }

    final header = rows.first
        .map((column) => column.trim().toLowerCase())
        .toList(growable: false);
    final idIndex = _columnIndex(header, 'id');
    final codeIndex = _columnIndex(header, 'codigo');
    final nameIndex = _columnIndex(header, 'denominacao');
    final addressIndex = _columnIndex(header, 'endereco');
    final latitudeIndex = _columnIndex(header, 'lat');
    final longitudeIndex = _columnIndex(header, 'long');
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

  int _columnIndex(List<String> header, String column) {
    final index = header.indexOf(column);
    if (index < 0) {
      throw FormatException('Coluna "$column" ausente em $assetPath');
    }
    return index;
  }
}

/// Divide o conteúdo CSV em linhas e colunas, respeitando campos entre aspas.
List<List<String>> _parseRows(String content) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;

  for (var index = 0; index < content.length; index++) {
    final character = content[index];

    if (inQuotes) {
      if (character == '"') {
        if (index + 1 < content.length && content[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(character);
      }
      continue;
    }

    switch (character) {
      case '"':
        inQuotes = true;
      case ',':
        row.add(field.toString());
        field.clear();
      case '\n':
        row.add(field.toString());
        field.clear();
        rows.add(row);
        row = <String>[];
      case '\r':
        break;
      default:
        field.write(character);
    }
  }

  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }

  return rows;
}
