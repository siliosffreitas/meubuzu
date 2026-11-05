import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/features/map/data/user_coordinates.dart';
import 'package:meubuzu/features/map/data/user_location_repository.dart';
import 'package:meubuzu/features/map/presentation/map_location_view_model.dart';

const _position = UserCoordinates(latitude: -5.0629, longitude: -42.7932);

class _FakeUserLocationRepository implements UserLocationRepository {
  _FakeUserLocationRepository({this.position, this.failure, this.error});

  UserCoordinates? position;
  UserLocationFailure? failure;
  Object? error;

  final _controller = StreamController<UserCoordinates>.broadcast();

  bool refreshCalled = false;
  bool? lastRequestPermission;
  bool openLocationSettingsCalled = false;
  bool openAppSettingsCalled = false;

  @override
  Stream<UserCoordinates> get location => _controller.stream;

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
  }
}

void main() {
  group('MapLocationViewModel', () {
    const failures = {
      UserLocationFailure.noGpsHardware: MapLocationStatus.noGpsHardware,
      UserLocationFailure.serviceDisabled: MapLocationStatus.serviceDisabled,
      UserLocationFailure.permissionDenied: MapLocationStatus.permissionDenied,
      UserLocationFailure.permissionDeniedForever:
          MapLocationStatus.permissionDeniedForever,
      UserLocationFailure.unavailable: MapLocationStatus.unavailable,
    };

    for (final entry in failures.entries) {
      test('falha ${entry.key.name} vira ${entry.value.name}', () async {
        final repository = _FakeUserLocationRepository(failure: entry.key);
        final viewModel = MapLocationViewModel(repository);
        addTearDown(viewModel.dispose);
        addTearDown(repository.dispose);

        await viewModel.initialize();
        await pumpEventQueue();

        expect(viewModel.status, entry.value);
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

      expect(viewModel.status, MapLocationStatus.ready);
      expect(viewModel.isReady, isTrue);
      expect(viewModel.position?.latitude, _position.latitude);
      expect(viewModel.position?.longitude, _position.longitude);
    });

    test('initialize sinaliza carregamento antes da resposta', () async {
      final repository = _FakeUserLocationRepository(position: _position);
      final viewModel = MapLocationViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.dispose);

      final statuses = <MapLocationStatus>[];
      viewModel.addListener(() => statuses.add(viewModel.status));

      final future = viewModel.initialize();
      expect(viewModel.status, MapLocationStatus.checking);

      await future;
      await pumpEventQueue();

      expect(statuses, [MapLocationStatus.checking, MapLocationStatus.ready]);
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
      expect(viewModel.status, MapLocationStatus.permissionDenied);
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

      expect(viewModel.status, MapLocationStatus.unavailable);
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
