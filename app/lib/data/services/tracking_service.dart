import 'package:flutter/services.dart';

import '../../domain/contracts/contracts.dart';
import '../../domain/models/bus.dart';
import '../../domain/models/bus_position.dart';
import '../../domain/models/line.dart';
import '../utils/csv_catalog.dart';

/// Contrato de consulta das posições dos ônibus.
abstract interface class TrackingService implements Service {
  /// Retorna as posições mais recentes das [lines] capturadas até [at].
  ///
  /// A consulta usa os arquivos de `assets/locations`, escolhidos pelo dia da
  /// semana de [at] (ou do relógio atual), e considera apenas a janela de
  /// [AssetTrackingService.window] minutos antes da hora da consulta. Posições
  /// posteriores a [at] são descartadas.
  ///
  /// Cada ônibus aparece uma única vez, com a captura mais recente da janela.
  Future<List<BusPosition>> findPositions(List<Line> lines, {DateTime? at});
}

/// Implementação que lê as posições de `assets/locations`.
///
/// Cada arquivo cobre um dia de referência e não possui cabeçalho. As colunas
/// são: label do ônibus, código da linha (`codigoLinha`), código do ônibus,
/// data/hora de geração, latitude, longitude e data/hora de captura.
class AssetTrackingService implements TrackingService {
  AssetTrackingService({
    AssetBundle? bundle,
    this.assetDirectory = 'assets/locations',
    this.window = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _bundle = bundle ?? rootBundle,
       _clock = clock ?? DateTime.now;

  final AssetBundle _bundle;
  final String assetDirectory;

  /// Intervalo consultado antes da hora de referência.
  final Duration window;

  final DateTime Function() _clock;

  /// Índices já lidos, por arquivo. Guarda o próprio future para evitar
  /// leituras duplicadas do asset (como em `AssetRouteService`).
  final Map<String, Future<_PositionIndex>> _indexes = {};

  /// Arquivo de posições correspondente a cada dia da semana.
  ///
  /// O dia 01/06/2023 foi uma quinta-feira, então os arquivos estão
  /// deslocados em relação ao número do dia.
  static const Map<int, String> filesByWeekday = {
    DateTime.monday: 'positions_2023_06_05.csv',
    DateTime.tuesday: 'positions_2023_06_06.csv',
    DateTime.wednesday: 'positions_2023_06_07.csv',
    DateTime.thursday: 'positions_2023_06_01.csv',
    DateTime.friday: 'positions_2023_06_02.csv',
    DateTime.saturday: 'positions_2023_06_03.csv',
    DateTime.sunday: 'positions_2023_06_04.csv',
  };

  @override
  Future<List<BusPosition>> findPositions(
    List<Line> lines, {
    DateTime? at,
  }) async {
    final lineCodes = <String>{
      for (final line in lines) normalizeLineCode(line.id),
    }..remove('');
    if (lineCodes.isEmpty) {
      return const [];
    }

    final reference = at ?? _clock();
    final fileName = filesByWeekday[reference.weekday];
    if (fileName == null) {
      return const [];
    }

    final index = await (_indexes[fileName] ??= _loadIndex(fileName));
    final referenceSeconds = _secondsOfDay(reference);
    final windowSeconds = window.inSeconds;

    // Mantém apenas a captura mais recente de cada ônibus dentro da janela.
    final latestByBus = <String, _PositionRow>{};
    for (final lineCode in lineCodes) {
      for (final row in index.byLineCode[lineCode] ?? const []) {
        final elapsed = referenceSeconds - row.capturedSeconds;
        if (elapsed < 0 || elapsed > windowSeconds) {
          continue;
        }

        final key = '${row.lineCode}:${row.busCode}';
        final current = latestByBus[key];
        if (current == null || row.capturedSeconds > current.capturedSeconds) {
          latestByBus[key] = row;
        }
      }
    }

    final positions = [for (final row in latestByBus.values) row.toPosition()]
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));

    return List<BusPosition>.unmodifiable(positions);
  }

  Future<_PositionIndex> _loadIndex(String fileName) async {
    final String content;
    try {
      content = await _bundle.loadString(_assetPathFor(fileName));
    } catch (_) {
      // Dias sem arquivo disponível simplesmente não possuem posições.
      return const _PositionIndex({});
    }

    final byLineCode = <String, List<_PositionRow>>{};
    for (final row in parseCsvRows(content)) {
      if (row.length < 7) {
        continue;
      }
      if (row.every((value) => value.trim().isEmpty)) {
        continue;
      }

      final lineCode = normalizeLineCode(row[1]);
      final busCode = row[2].trim();
      final latitude = double.tryParse(row[4].trim());
      final longitude = double.tryParse(row[5].trim());
      final capturedRaw = row[6].trim();
      final capturedAt = DateTime.tryParse(capturedRaw);
      final capturedSeconds = _secondsOfDayFromTimestamp(capturedRaw);

      if (lineCode.isEmpty ||
          busCode.isEmpty ||
          latitude == null ||
          longitude == null ||
          capturedAt == null ||
          capturedSeconds == null) {
        continue;
      }

      (byLineCode[lineCode] ??= <_PositionRow>[]).add(
        _PositionRow(
          lineCode: lineCode,
          busCode: busCode,
          latitude: latitude,
          longitude: longitude,
          capturedAt: capturedAt,
          capturedSeconds: capturedSeconds,
          generatedAt: DateTime.tryParse(row[3].trim()),
        ),
      );
    }

    return _PositionIndex(byLineCode);
  }

  String _assetPathFor(String fileName) {
    final directory = assetDirectory.replaceFirst(RegExp(r'/+$'), '');
    return '$directory/$fileName';
  }

  static final RegExp _timePattern = RegExp(r'T(\d{2}):(\d{2}):(\d{2})');

  /// Lê a hora do dia direto do texto do CSV, sem depender do fuso.
  static int? _secondsOfDayFromTimestamp(String raw) {
    final match = _timePattern.firstMatch(raw);
    if (match == null) {
      return null;
    }
    return int.parse(match.group(1)!) * 3600 +
        int.parse(match.group(2)!) * 60 +
        int.parse(match.group(3)!);
  }

  /// Segundos desde a meia-noite no relógio local da consulta.
  static int _secondsOfDay(DateTime value) =>
      value.hour * 3600 + value.minute * 60 + value.second;
}

/// Normaliza o `codigoLinha` para comparar valores com e sem zeros à esquerda.
String normalizeLineCode(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final withoutLeadingZeros = trimmed.replaceFirst(RegExp(r'^0+'), '');
  return withoutLeadingZeros.isEmpty ? '0' : withoutLeadingZeros;
}

/// Posições indexadas pelo `codigoLinha`.
class _PositionIndex {
  const _PositionIndex(this.byLineCode);

  final Map<String, List<_PositionRow>> byLineCode;
}

/// Linha do arquivo de posições já interpretada.
class _PositionRow {
  const _PositionRow({
    required this.lineCode,
    required this.busCode,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    required this.capturedSeconds,
    required this.generatedAt,
  });

  final String lineCode;
  final String busCode;
  final double latitude;
  final double longitude;
  final DateTime capturedAt;
  final int capturedSeconds;
  final DateTime? generatedAt;

  BusPosition toPosition() {
    return BusPosition(
      bus: Bus(code: busCode),
      latitude: latitude,
      longitude: longitude,
      capturedAt: capturedAt,
      generatedAt: generatedAt,
    );
  }
}
