import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/features/map/data/location_service.dart';
import 'package:meubuzu/features/map/data/user_coordinates.dart';
import 'package:meubuzu/features/map/data/user_location_repository.dart';

const _position = UserCoordinates(latitude: -5.0629, longitude: -42.7932);

class _FakeLocationService implements LocationService {
  _FakeLocationService({
    this.hasGps = true,
    this.serviceEnabled = true,
    this.permission = LocationPermissionStatus.denied,
    this.permissionAfterRequest = LocationPermissionStatus.granted,
    this.position = _position,
    this.throwOnPosition = false,
  });

  bool hasGps;
  bool serviceEnabled;
  LocationPermissionStatus permission;
  LocationPermissionStatus permissionAfterRequest;
  UserCoordinates? position;
  bool throwOnPosition;

  bool checkPermissionCalled = false;
  bool requestPermissionCalled = false;
  bool currentPositionCalled = false;
  bool openLocationSettingsCalled = false;
  bool openAppSettingsCalled = false;

  @override
  Future<bool> hasGpsHardware() async => hasGps;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermissionStatus> checkPermission() async {
    checkPermissionCalled = true;
    return permission;
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    requestPermissionCalled = true;
    permission = permissionAfterRequest;
    return permissionAfterRequest;
  }

  @override
  Future<UserCoordinates?> currentPosition() async {
    currentPositionCalled = true;
    if (throwOnPosition) {
      throw StateError('falha inesperada');
    }
    return position;
  }

  @override
  Future<void> openLocationSettings() async {
    openLocationSettingsCalled = true;
  }

  @override
  Future<void> openAppSettings() async {
    openAppSettingsCalled = true;
  }
}

Matcher _failsWith(UserLocationFailure failure) {
  return isA<UserLocationException>().having(
    (error) => error.failure,
    'failure',
    failure,
  );
}

void main() {
  group('DeviceUserLocationRepository', () {
    test(
      'sem GPS publica falha e não verifica serviço nem permissão',
      () async {
        final service = _FakeLocationService(hasGps: false);
        final repository = DeviceUserLocationRepository(service);
        addTearDown(repository.dispose);

        final expectation = expectLater(
          repository.location,
          emitsError(_failsWith(UserLocationFailure.noGpsHardware)),
        );

        await repository.refresh();
        await expectation;

        expect(service.checkPermissionCalled, isFalse);
        expect(service.requestPermissionCalled, isFalse);
        expect(service.currentPositionCalled, isFalse);
      },
    );

    test('serviço de localização desligado publica falha', () async {
      final service = _FakeLocationService(serviceEnabled: false);
      final repository = DeviceUserLocationRepository(service);
      addTearDown(repository.dispose);

      final expectation = expectLater(
        repository.location,
        emitsError(_failsWith(UserLocationFailure.serviceDisabled)),
      );

      await repository.refresh();
      await expectation;

      expect(service.checkPermissionCalled, isFalse);
      expect(service.currentPositionCalled, isFalse);
    });

    test('pede permissão e publica a posição obtida', () async {
      final service = _FakeLocationService();
      final repository = DeviceUserLocationRepository(service);
      addTearDown(repository.dispose);

      final expectation = expectLater(repository.location, emits(_position));

      await repository.refresh();
      await expectation;

      expect(service.requestPermissionCalled, isTrue);
      expect(service.currentPositionCalled, isTrue);
    });

    test('permissão negada publica falha e não busca a posição', () async {
      final service = _FakeLocationService(
        permissionAfterRequest: LocationPermissionStatus.denied,
      );
      final repository = DeviceUserLocationRepository(service);
      addTearDown(repository.dispose);

      final expectation = expectLater(
        repository.location,
        emitsError(_failsWith(UserLocationFailure.permissionDenied)),
      );

      await repository.refresh();
      await expectation;

      expect(service.currentPositionCalled, isFalse);
    });

    test('permissão negada permanentemente não pede novamente', () async {
      final service = _FakeLocationService(
        permission: LocationPermissionStatus.deniedForever,
      );
      final repository = DeviceUserLocationRepository(service);
      addTearDown(repository.dispose);

      final expectation = expectLater(
        repository.location,
        emitsError(_failsWith(UserLocationFailure.permissionDeniedForever)),
      );

      await repository.refresh();
      await expectation;

      expect(service.requestPermissionCalled, isFalse);
    });

    test('permissão já concedida não abre o diálogo', () async {
      final service = _FakeLocationService(
        permission: LocationPermissionStatus.granted,
      );
      final repository = DeviceUserLocationRepository(service);
      addTearDown(repository.dispose);

      final expectation = expectLater(repository.location, emits(_position));

      await repository.refresh();
      await expectation;

      expect(service.requestPermissionCalled, isFalse);
    });

    test('revalidar sem pedir permissão não abre o diálogo', () async {
      final service = _FakeLocationService();
      final repository = DeviceUserLocationRepository(service);
      addTearDown(repository.dispose);

      final expectation = expectLater(
        repository.location,
        emitsError(_failsWith(UserLocationFailure.permissionDenied)),
      );

      await repository.refresh(requestPermission: false);
      await expectation;

      expect(service.requestPermissionCalled, isFalse);
    });

    test('posição indisponível publica falha', () async {
      final service = _FakeLocationService(
        permission: LocationPermissionStatus.granted,
        position: null,
      );
      final repository = DeviceUserLocationRepository(service);
      addTearDown(repository.dispose);

      final expectation = expectLater(
        repository.location,
        emitsError(_failsWith(UserLocationFailure.unavailable)),
      );

      await repository.refresh();
      await expectation;
    });

    test('exceção do serviço publica falha de indisponibilidade', () async {
      final service = _FakeLocationService(
        permission: LocationPermissionStatus.granted,
        throwOnPosition: true,
      );
      final repository = DeviceUserLocationRepository(service);
      addTearDown(repository.dispose);

      final expectation = expectLater(
        repository.location,
        emitsError(_failsWith(UserLocationFailure.unavailable)),
      );

      await repository.refresh();
      await expectation;
    });

    test('guarda a última posição para novos ouvintes', () async {
      final service = _FakeLocationService(
        permission: LocationPermissionStatus.granted,
      );
      final repository = DeviceUserLocationRepository(service);
      addTearDown(repository.dispose);

      await repository.refresh();

      await expectLater(repository.location, emits(_position));
    });

    test('abre as configurações de localização e do app', () async {
      final service = _FakeLocationService();
      final repository = DeviceUserLocationRepository(service);
      addTearDown(repository.dispose);

      await repository.openLocationSettings();
      await repository.openAppSettings();

      expect(service.openLocationSettingsCalled, isTrue);
      expect(service.openAppSettingsCalled, isTrue);
    });

    test('dispose encerra o stream', () async {
      final repository = DeviceUserLocationRepository(_FakeLocationService());

      repository.dispose();

      await expectLater(repository.location, emitsDone);
    });
  });
}
