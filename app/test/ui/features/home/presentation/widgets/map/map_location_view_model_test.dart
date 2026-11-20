import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/domain/models/bus_stop.dart';
import 'package:meubuzu/domain/models/user_coordinates.dart';
import 'package:meubuzu/domain/repositories/user_location_repository.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_location_state.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_location_view_model.dart';

const _position = UserCoordinates(latitude: -5.0629, longitude: -42.7932);
const _southwest = UserCoordinates(latitude: -5.08, longitude: -42.85);
const _northeast = UserCoordinates(latitude: -5.05, longitude: -42.75);
const _busStop = BusStop(
  code: '2362',
  name: 'T-SANTA FÉ',
  address: 'Rua B, Teresina - PI',
  latitude: -5.0629,
  longitude: -42.7932,
);

class _FakeUserLocationRepository implements UserLocationRepository {
  _FakeUserLocationRepository({this.position, this.failure, this.error});

  UserCoordinates? position;
  UserLocationFailure? failure;
  Object? error;

  final _controller = StreamController<UserCoordinates>.broadcast();
  final _visibleStopsController = StreamController<List<BusStop>>.broadcast();

  bool refreshCalled = false;
  bool? lastRequestPermission;
  bool openLocationSettingsCalled = false;
  bool openAppSettingsCalled = false;
  int clearVisibleStopsCalls = 0;
  final visibleAreaRequests =
      <({UserCoordinates southwest, UserCoordinates northeast})>[];

  @override
  Stream<UserCoordinates> get location => _controller.stream;

  @override
  Stream<List<BusStop>> get visibleStops => _visibleStopsController.stream;

  void emitVisibleStops(List<BusStop> stops) {
    _visibleStopsController.add(stops);
  }

  void emitVisibleStopsError(Object error) {
    _visibleStopsController.addError(error);
  }

  @override
  Future<void> refresh({bool requestPermission = true}) async {
    refreshCalled = true;
    lastRequestPermission = requestPermission;

    final error = this.error;
    if (error != null) {
      _controller.addError(error);
      return;
    }

    final failure = this.failure;
    if (failure != null) {
      _controller.addError(UserLocationException(failure));
      return;
    }

    final position = this.position;
    if (position != null) {
      _controller.add(position);
    }
  }

  @override
  Future<void> updateVisibleArea({
    required UserCoordinates southwest,
    required UserCoordinates northeast,
  }) async {
    visibleAreaRequests.add((southwest: southwest, northeast: northeast));
  }

  @override
  void clearVisibleStops() {
    clearVisibleStopsCalls++;
  }

  @override
  Future<void> openLocationSettings() async {
    openLocationSettingsCalled = true;
  }

  @override
  Future<void> openAppSettings() async {
    openAppSettingsCalled = true;
  }

  @override
  void dispose() {
    _controller.close();
    _visibleStopsController.close();
  }
}

void main() {
  group('MapLocationViewModel', () {
    const failures = {
      UserLocationFailure.noGpsHardware: MapLocationNoGpsHardware(),
      UserLocationFailure.serviceDisabled: MapLocationServiceDisabled(),
      UserLocationFailure.permissionDenied: MapLocationPermissionDenied(),
      UserLocationFailure.permissionDeniedForever:
          MapLocationPermissionDeniedForever(),
      UserLocationFailure.unavailable: MapLocationUnavailable(),
    };

    for (final entry in failures.entries) {
      test('falha ${entry.key.name} vira ${entry.value.runtimeType}', () async {
        final repository = _FakeUserLocationRepository(failure: entry.key);
        final viewModel = MapLocationViewModel(repository);
        addTearDown(viewModel.dispose);
        addTearDown(repository.dispose);

        await viewModel.initialize();
        await pumpEventQueue();

        expect(viewModel.state.runtimeType, entry.value.runtimeType);
        expect(viewModel.position, isNull);
        expect(viewModel.isReady, isFalse);
      });
    }

    test('posição publicada deixa o mapa pronto', () async {
      final repository = _FakeUserLocationRepository(position: _position);
      final viewModel = MapLocationViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      await viewModel.initialize();
      await pumpEventQueue();

      expect(viewModel.state, isA<MapLocationReady>());
      expect(viewModel.isReady, isTrue);
      expect(viewModel.position?.latitude, _position.latitude);
      expect(viewModel.position?.longitude, _position.longitude);
    });

    test('paradas da área visível ficam disponíveis sem novo estado', () async {
      final repository = _FakeUserLocationRepository(position: _position);
      final viewModel = MapLocationViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      await viewModel.initialize();
      await pumpEventQueue();

      repository.emitVisibleStops(const [_busStop]);
      await pumpEventQueue();

      expect(viewModel.visibleStops, const [_busStop]);
      expect(viewModel.state, isA<MapLocationReady>());
      expect(viewModel.position, same(_position));
      expect(viewModel.isReady, isTrue);
    });

    test('lista vazia de paradas mantém apenas a localização pronta', () async {
      final repository = _FakeUserLocationRepository(position: _position);
      final viewModel = MapLocationViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      await viewModel.initialize();
      await pumpEventQueue();

      repository.emitVisibleStops(const []);
      await pumpEventQueue();

      expect(viewModel.state.runtimeType, MapLocationReady);
      expect(viewModel.visibleStops, isEmpty);
      expect(viewModel.isReady, isTrue);
    });

    test('paradas da área visível aparecem mesmo antes da posição', () async {
      final repository = _FakeUserLocationRepository();
      final viewModel = MapLocationViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      repository.emitVisibleStops(const [_busStop]);
      await pumpEventQueue();

      expect(viewModel.visibleStops, const [_busStop]);
      expect(viewModel.state, isA<MapLocationIdle>());
      expect(viewModel.isReady, isFalse);
    });

    test('erro nas paradas não invalida a localização', () async {
      final repository = _FakeUserLocationRepository(position: _position);
      final viewModel = MapLocationViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      await viewModel.initialize();
      await pumpEventQueue();

      repository.emitVisibleStopsError(StateError('catálogo indisponível'));
      await pumpEventQueue();

      expect(viewModel.position, same(_position));
      expect(viewModel.visibleStops, isEmpty);
      expect(viewModel.isReady, isTrue);
    });

    test('zooms abaixo do mínimo limpam as paradas da área visível', () async {
      final repository = _FakeUserLocationRepository(position: _position);
      final viewModel = MapLocationViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      await viewModel.updateVisibleArea(
        southwest: _southwest,
        northeast: _northeast,
        zoom: minVisibleStopsZoom - 0.1,
      );

      expect(repository.clearVisibleStopsCalls, 1);
      expect(repository.visibleAreaRequests, isEmpty);
    });

    test('zoom mínimo consulta a área visível', () async {
      final repository = _FakeUserLocationRepository(position: _position);
      final viewModel = MapLocationViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      await viewModel.updateVisibleArea(
        southwest: _southwest,
        northeast: _northeast,
        zoom: minVisibleStopsZoom,
      );

      expect(repository.clearVisibleStopsCalls, 0);
      final request = repository.visibleAreaRequests.single;
      expect(request.southwest, same(_southwest));
      expect(request.northeast, same(_northeast));
    });

    test('limpar a área visível repassa ao repositório', () async {
      final repository = _FakeUserLocationRepository(position: _position);
      final viewModel = MapLocationViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      viewModel.clearVisibleStops();

      expect(repository.clearVisibleStopsCalls, 1);
    });

    test('initialize sinaliza carregamento antes da resposta', () async {
      final repository = _FakeUserLocationRepository(position: _position);
      final viewModel = MapLocationViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      final states = <MapLocationState>[];
      viewModel.addListener(() => states.add(viewModel.state));

      final future = viewModel.initialize();
      expect(viewModel.state, isA<MapLocationChecking>());

      await future;
      await pumpEventQueue();

      expect(states, hasLength(2));
      expect(states.first, isA<MapLocationChecking>());
      expect(states.last, isA<MapLocationReady>());
    });

    test('revalidar sem pedir permissão repassa ao repositório', () async {
      final repository = _FakeUserLocationRepository(
        failure: UserLocationFailure.permissionDenied,
      );
      final viewModel = MapLocationViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      await viewModel.initialize(requestPermission: false);
      await pumpEventQueue();

      expect(repository.refreshCalled, isTrue);
      expect(repository.lastRequestPermission, isFalse);
      expect(viewModel.state, isA<MapLocationPermissionDenied>());
    });

    test('erro desconhecido gera estado indisponível', () async {
      final repository = _FakeUserLocationRepository(
        error: StateError('falha inesperada'),
      );
      final viewModel = MapLocationViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      await viewModel.initialize();
      await pumpEventQueue();

      expect(viewModel.state, isA<MapLocationUnavailable>());
      expect(viewModel.position, isNull);
    });

    test('abre as configurações de localização e do app', () async {
      final repository = _FakeUserLocationRepository();
      final viewModel = MapLocationViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      await viewModel.openLocationSettings();
      await viewModel.openAppSettings();

      expect(repository.openLocationSettingsCalled, isTrue);
      expect(repository.openAppSettingsCalled, isTrue);
    });
  });
}
