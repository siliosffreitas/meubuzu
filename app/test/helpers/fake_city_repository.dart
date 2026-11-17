import 'package:flutter/foundation.dart';
import 'package:meubuzu/domain/models/city.dart';
import 'package:meubuzu/domain/repositories/city_repository.dart';

/// Catálogo de cidades em memória para testes.
///
/// Registra quantas vezes a lista foi buscada e permite simular falha com
/// [error] e latência com [latency].
class FakeCityRepository extends ChangeNotifier implements CityRepository {
  FakeCityRepository({
    List<City>? cities,
    this.error,
    this.latency = Duration.zero,
  }) : _cities = cities ?? const [];

  final List<City> _cities;

  /// Quando definido, [fetchActiveCities] lança o erro informado.
  final Object? error;

  /// Espera antes de responder, para exercitar o estado de carregamento.
  final Duration latency;

  int fetchCalls = 0;

  @override
  Future<List<City>> fetchActiveCities() async {
    fetchCalls++;
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return _cities;
  }
}
