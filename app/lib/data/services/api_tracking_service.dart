import '../../domain/models/bus.dart';
import '../../domain/models/bus_position.dart';
import '../../domain/models/line.dart';
import '../../domain/repositories/auth_repository.dart';
import '../config/api_paths.dart';
import 'api_client.dart';
import 'tracking_service.dart';

/// Consulta as posições no backend da cidade selecionada, usando o `sgLinha`
/// das linhas acompanhadas como parâmetro.
///
/// O app não escolhe arquivos nem conhece a fonte: o backend devolve o mesmo
/// envelope para CSV de demonstração e para o futuro banco de posições.
class ApiTrackingService implements TrackingService {
  ApiTrackingService(this._client, this._auth);

  final ApiClient _client;
  final AuthRepository _auth;

  @override
  Future<List<BusPosition>> findPositions(List<Line> lines, {DateTime? at}) async {
    if (lines.isEmpty) {
      return const <BusPosition>[];
    }

    final city = _auth.selectedCity;
    if (city == null || city.slug.isEmpty) {
      throw StateError('É necessário escolher uma cidade para consultar posições.');
    }

    final codes = <String>[];
    for (final line in lines) {
      final code = normalizeLineCode(line.boardingCode ?? '');
      if (code.isNotEmpty && !codes.contains(code)) {
        codes.add(code);
      }
    }
    if (codes.isEmpty) {
      return const <BusPosition>[];
    }

    final uri = Uri.parse(ApiPaths.city(city.slug, 'positions')).replace(
      queryParameters: {'codes': codes.join(',')},
    );
    final body = await _client.get(uri.toString(), accessToken: _auth.accessToken);

    final rawLines = body['lines'];
    if (rawLines is! List) {
      return const <BusPosition>[];
    }

    final positions = <BusPosition>[];
    for (final rawLine in rawLines) {
      if (rawLine is! Map<String, dynamic>) {
        continue;
      }
      positions.addAll(_parseLine(rawLine));
    }

    positions.sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    return List<BusPosition>.unmodifiable(positions);
  }

  List<BusPosition> _parseLine(Map<String, dynamic> line) {
    final blockLineCode = normalizeLineCode(
      _text(line['boardingCode']) ?? _text(line['requestedId']) ?? '',
    );
    final blockDataMode = _text(line['dataMode']);
    final blockSource = _text(line['source']);
    final blockIsStale = line['isStale'] as bool? ?? false;

    final rawPositions = line['positions'];
    if (rawPositions is! List) {
      return const <BusPosition>[];
    }

    final parsed = <BusPosition>[];
    for (final raw in rawPositions) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }

      final lineCode = normalizeLineCode(
        _text(raw['boardingCode']) ?? blockLineCode,
      );
      final vehicleCode = _text(raw['vehicleCode']);
      final latitude = (raw['latitude'] as num?)?.toDouble();
      final longitude = (raw['longitude'] as num?)?.toDouble();
      final capturedAt = DateTime.tryParse(_text(raw['capturedAt']) ?? '');
      if (lineCode.isEmpty ||
          vehicleCode == null ||
          vehicleCode.isEmpty ||
          latitude == null ||
          longitude == null ||
          capturedAt == null) {
        continue;
      }

      parsed.add(
        BusPosition(
          bus: Bus(code: vehicleCode),
          lineCode: lineCode,
          latitude: latitude,
          longitude: longitude,
          capturedAt: capturedAt,
          generatedAt: DateTime.tryParse(_text(raw['generatedAt']) ?? ''),
          receivedAt: DateTime.tryParse(_text(raw['receivedAt']) ?? ''),
          speed: (raw['speed'] as num?)?.toDouble(),
          heading: (raw['heading'] as num?)?.toDouble(),
          previousLatitude: (raw['previousLatitude'] as num?)?.toDouble(),
          previousLongitude: (raw['previousLongitude'] as num?)?.toDouble(),
          isStale: raw['isStale'] as bool? ?? blockIsStale,
          dataMode: _text(raw['dataMode']) ?? blockDataMode,
          source: _text(raw['source']) ?? blockSource,
        ),
      );
    }
    return parsed;
  }

  static String? _text(Object? value) {
    if (value == null) {
      return null;
    }
    return value.toString();
  }
}
