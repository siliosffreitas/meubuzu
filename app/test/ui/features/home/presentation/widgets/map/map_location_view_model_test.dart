import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/data/models/bus_stop.dart';
import 'package:meubuzu/data/models/user_coordinates.dart';
import 'package:meubuzu/domain/repositories/user_location_repository.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_location_state.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_location_view_model.dart';

const _position = UserCoordinates(latitude: -5.0629, longitude: -42.7932);
const _busStop = BusStop(
  id: '1',
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
  Completer<void>? refreshGate;

  final _controller = StreamController<UserCoordinates>.broadcast();
  final _nearbyStopsController = StreamController<List<BusStop>>.broadcast();

  bool refreshCalled = false;
  bool? lastRequestPermission;
  bool openLocationSettingsCalled = false;
  bool openAppSettingsCalled = false;

  @override
  Stream<UserCoordinates> get location => _controller.stream;

  @override
  Stream<List<BusStop>> get nearbyStops => _nearbyStopsController.stream;

  void emitNearbyStops(List<BusStop> stops) {
    _nearbyStopsController.add(stops);
  }

  void emitNearbyStopsError(Object error) {
    _nearbyStopsController.addError(error);
  }

  @override
  Future<void> refresh({bool requestPermission = true}) async {
    refreshCalled = true;
    lastRequestPermission = requestPermission;

    final gate = refreshGate;
    if (gate != null) {
      await gate.future;
    }

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
    _nearbyStopsController.close();
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

    test('paradas próximas geram um estado específico', () async {
      final repository = _FakeUserLocationRepository(position: _position);
      final viewModel = MapLocationViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      await viewModel.initialize();
      await pumpEventQueue();

      repository.emitNearbyStops(const [_busStop]);
      await pumpEventQueue();

      expect(viewModel.state, isA<MapLocationNearbyStopsReady>());
      expect(viewModel.state, isA<MapLocationReady>());
      expect(viewModel.nearbyStops, const [_busStop]);
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

      repository.emitNearbyStops(const []);
      await pumpEventQueue();

      expect(viewModel.state.runtimeType, MapLocationReady);
      expect(viewModel.nearbyStops, isEmpty);
      expect(viewModel.isReady, isTrue);
    });

    test(
      'paradas recebidas antes da posição aparecem quando ela chega',
      () async {
        final gate = Completer<void>();
        final repository = _FakeUserLocationRepository(position: _position)
          ..refreshGate = gate;
        final viewModel = MapLocationViewModel(repository);
        addTearDown(viewModel.dispose);
        addTearDown(repository.dispose);

        final initialization = viewModel.initialize();

        repository.emitNearbyStops(const [_busStop]);
        await pumpEventQueue();

        expect(viewModel.state, isA<MapLocationChecking>());
        expect(viewModel.nearbyStops, isEmpty);

        gate.complete();
        await initialization;
        await pumpEventQueue();

        expect(viewModel.state, isA<MapLocationNearbyStopsReady>());
        expect(viewModel.nearbyStops, const [_busStop]);
      },
    );

    test('erro nas paradas não invalida a localização', () async {
      final repository = _FakeUserLocationRepository(position: _position);
      final viewModel = MapLocationViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      await viewModel.initialize();
      await pumpEventQueue();

      repository.emitNearbyStopsError(StateError('catálogo indisponível'));
      await pumpEventQueue();

      expect(viewModel.position, same(_position));
      expect(viewModel.nearbyStops, isEmpty);
      expect(viewModel.isReady, isTrue);
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
