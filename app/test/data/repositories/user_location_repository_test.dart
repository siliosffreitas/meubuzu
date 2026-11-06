import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/domain/models/bus_stop.dart';
import 'package:meubuzu/domain/models/user_coordinates.dart';
import 'package:meubuzu/data/repositories/user_location_repository.dart';
import 'package:meubuzu/data/services/bus_stop_service.dart';
import 'package:meubuzu/data/services/location_service.dart';
import 'package:meubuzu/domain/repositories/user_location_repository.dart';

const _position = UserCoordinates(latitude: -5.0629, longitude: -42.7932);
const _otherPosition = UserCoordinates(latitude: -5.07, longitude: -42.8);
const _busStop = BusStop(
  id: '1',
  code: '2362',
  name: 'T-SANTA FÉ',
  address: 'Rua B, Teresina - PI',
  latitude: -5.0629,
  longitude: -42.7932,
);
const _otherBusStop = BusStop(
  id: '2',
  code: '1848',
  name: 'CONJUNTO BENTINHO 1',
  address: 'Rua Seis, Teresina - PI',
  latitude: -5.07,
  longitude: -42.8,
);

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

class _FakeBusStopService implements BusStopService {
  _FakeBusStopService({
    this.stops = const [],
    this.error,
    this.manualResponses = false,
  });

  List<BusStop> stops;
  Object? error;
  bool manualResponses;
  final requests = <UserCoordinates>[];
  final _responses = <Completer<List<BusStop>>>[];

  @override
  Future<List<BusStop>> findNearby(
    UserCoordinates position, {
    double maxDistanceInMeters = nearbyBusStopsRadiusInMeters,
  }) {
    requests.add(position);
    if (manualResponses) {
      final response = Completer<List<BusStop>>();
      _responses.add(response);
      return response.future;
    }
    final error = this.error;
    if (error != null) {
      return Future<List<BusStop>>.error(error);
    }
    return Future<List<BusStop>>.value(stops);
  }

  void complete(int index, List<BusStop> stops) {
    _responses[index].complete(stops);
  }

  @override
  Future<List<BusStop>> search(String query) async {
    return stops;
  }
}

DeviceUserLocationRepository _repository(
  _FakeLocationService service, {
  _FakeBusStopService? busStopService,
}) {
  return DeviceUserLocationRepository(
    service,
    busStopService ?? _FakeBusStopService(),
  );
}

void main() {
  group('DeviceUserLocationRepository', () {
    test(
      'sem GPS publica falha e não verifica serviço nem permissão',
      () async {
        final service = _FakeLocationService(hasGps: false);
        final repository = _repository(service);
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
      final repository = _repository(service);
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
      final repository = _repository(service);
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
      final repository = _repository(service);
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
      final repository = _repository(service);
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
      final repository = _repository(service);
      addTearDown(repository.dispose);

      final expectation = expectLater(repository.location, emits(_position));

      await repository.refresh();
      await expectation;

      expect(service.requestPermissionCalled, isFalse);
    });

    test('revalidar sem pedir permissão não abre o diálogo', () async {
      final service = _FakeLocationService();
      final repository = _repository(service);
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
      final repository = _repository(service);
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
      final repository = _repository(service);
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
      final repository = _repository(service);
      addTearDown(repository.dispose);

      await repository.refresh();

      await expectLater(repository.location, emits(_position));
    });

    test('abre as configurações de localização e do app', () async {
      final service = _FakeLocationService();
      final repository = _repository(service);
      addTearDown(repository.dispose);

      await repository.openLocationSettings();
      await repository.openAppSettings();

      expect(service.openLocationSettingsCalled, isTrue);
      expect(service.openAppSettingsCalled, isTrue);
    });

    test('publica as paradas próximas da posição obtida', () async {
      final service = _FakeLocationService(
        permission: LocationPermissionStatus.granted,
      );
      final busStopService = _FakeBusStopService(stops: const [_busStop]);
      final repository = _repository(service, busStopService: busStopService);
      addTearDown(repository.dispose);

      final expectation = expectLater(
        repository.nearbyStops,
        emits(const [_busStop]),
      );

      await repository.refresh();
      await expectation;

      expect(busStopService.requests, const [_position]);
    });

    test('guarda as últimas paradas para novos ouvintes', () async {
      final service = _FakeLocationService(
        permission: LocationPermissionStatus.granted,
      );
      final busStopService = _FakeBusStopService(stops: const [_busStop]);
      final repository = _repository(service, busStopService: busStopService);
      addTearDown(repository.dispose);

      await repository.refresh();
      await pumpEventQueue();

      await expectLater(repository.nearbyStops, emits(const [_busStop]));
    });

    test('ignora resposta antiga quando uma posição mais nova chega', () async {
      final service = _FakeLocationService(
        permission: LocationPermissionStatus.granted,
      );
      final busStopService = _FakeBusStopService(manualResponses: true);
      final repository = _repository(service, busStopService: busStopService);
      addTearDown(repository.dispose);

      final emissions = <List<BusStop>>[];
      final subscription = repository.nearbyStops.listen(emissions.add);
      addTearDown(subscription.cancel);

      await repository.refresh();

      service.position = _otherPosition;
      await repository.refresh();

      busStopService.complete(1, const [_otherBusStop]);
      await pumpEventQueue();
      busStopService.complete(0, const [_busStop]);
      await pumpEventQueue();

      expect(emissions, [
        const [_otherBusStop],
      ]);
    });

    test('erro ao consultar paradas é publicado no stream', () async {
      final service = _FakeLocationService(
        permission: LocationPermissionStatus.granted,
      );
      final busStopService = _FakeBusStopService(
        error: StateError('catálogo indisponível'),
      );
      final repository = _repository(service, busStopService: busStopService);
      addTearDown(repository.dispose);

      final expectation = expectLater(
        repository.nearbyStops,
        emitsError(isA<StateError>()),
      );

      await repository.refresh();
      await expectation;
    });

    test('não consulta paradas quando a localização falha', () async {
      final service = _FakeLocationService(hasGps: false);
      final busStopService = _FakeBusStopService();
      final repository = _repository(service, busStopService: busStopService);
      addTearDown(repository.dispose);

      await repository.refresh();

      expect(busStopService.requests, isEmpty);
    });

    test('dispose encerra o stream de localização', () async {
      final repository = _repository(_FakeLocationService());

      repository.dispose();

      await expectLater(repository.location, emitsDone);
    });

    test('dispose encerra o stream de paradas', () async {
      final repository = _repository(_FakeLocationService());

      repository.dispose();

      await expectLater(repository.nearbyStops, emitsDone);
    });
  });
}
