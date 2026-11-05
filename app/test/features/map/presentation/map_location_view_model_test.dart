import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/features/map/data/location_service.dart';
import 'package:meubuzu/features/map/presentation/map_location_view_model.dart';

const _position = UserCoordinates(latitude: -23.5505, longitude: -46.6333);

class _FakeLocationService implements LocationService {
  _FakeLocationService({
    this.hasGps = true,
    this.serviceEnabled = true,
    this.permission = LocationPermissionStatus.denied,
    this.permissionAfterRequest = LocationPermissionStatus.granted,
    this.position = _position,
  });

  bool hasGps;
  bool serviceEnabled;
  LocationPermissionStatus permission;
  LocationPermissionStatus permissionAfterRequest;
  UserCoordinates? position;

  bool checkPermissionCalled = false;
  bool requestPermissionCalled = false;
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
  Future<UserCoordinates?> currentPosition() async => position;

  @override
  Future<void> openLocationSettings() async {
    openLocationSettingsCalled = true;
  }

  @override
  Future<void> openAppSettings() async {
    openAppSettingsCalled = true;
  }
}

void main() {
  group('MapLocationViewModel', () {
    test('sem GPS não verifica serviço nem permissão', () async {
      final service = _FakeLocationService(hasGps: false);
      final viewModel = MapLocationViewModel(service);
      addTearDown(viewModel.dispose);

      await viewModel.initialize();

      expect(viewModel.status, MapLocationStatus.noGpsHardware);
      expect(service.checkPermissionCalled, isFalse);
      expect(service.requestPermissionCalled, isFalse);
    });

    test('com GPS desligado pede para ligar o serviço', () async {
      final service = _FakeLocationService(serviceEnabled: false);
      final viewModel = MapLocationViewModel(service);
      addTearDown(viewModel.dispose);

      await viewModel.initialize();

      expect(viewModel.status, MapLocationStatus.serviceDisabled);
      expect(service.checkPermissionCalled, isFalse);
      expect(service.requestPermissionCalled, isFalse);
    });

    test('pede permissão quando o GPS está ligado', () async {
      final service = _FakeLocationService();
      final viewModel = MapLocationViewModel(service);
      addTearDown(viewModel.dispose);

      await viewModel.initialize();

      expect(service.requestPermissionCalled, isTrue);
      expect(viewModel.status, MapLocationStatus.ready);
      expect(viewModel.position?.latitude, _position.latitude);
      expect(viewModel.position?.longitude, _position.longitude);
    });

    test('permissão negada mantém o aviso para o usuário', () async {
      final service = _FakeLocationService(
        permissionAfterRequest: LocationPermissionStatus.denied,
      );
      final viewModel = MapLocationViewModel(service);
      addTearDown(viewModel.dispose);

      await viewModel.initialize();

      expect(viewModel.status, MapLocationStatus.permissionDenied);
      expect(viewModel.position, isNull);
    });

    test('permissão negada permanentemente não pede novamente', () async {
      final service = _FakeLocationService(
        permission: LocationPermissionStatus.deniedForever,
      );
      final viewModel = MapLocationViewModel(service);
      addTearDown(viewModel.dispose);

      await viewModel.initialize();

      expect(viewModel.status, MapLocationStatus.permissionDeniedForever);
      expect(service.requestPermissionCalled, isFalse);
    });

    test('permissão já concedida não abre o diálogo', () async {
      final service = _FakeLocationService(
        permission: LocationPermissionStatus.granted,
      );
      final viewModel = MapLocationViewModel(service);
      addTearDown(viewModel.dispose);

      await viewModel.initialize();

      expect(service.requestPermissionCalled, isFalse);
      expect(viewModel.status, MapLocationStatus.ready);
    });

    test('revalidar sem pedir permissão não abre o diálogo', () async {
      final service = _FakeLocationService();
      final viewModel = MapLocationViewModel(service);
      addTearDown(viewModel.dispose);

      await viewModel.initialize(requestPermission: false);

      expect(service.requestPermissionCalled, isFalse);
      expect(viewModel.status, MapLocationStatus.permissionDenied);
    });

    test('posição indisponível gera estado de erro', () async {
      final service = _FakeLocationService(
        permission: LocationPermissionStatus.granted,
        position: null,
      );
      final viewModel = MapLocationViewModel(service);
      addTearDown(viewModel.dispose);

      await viewModel.initialize();

      expect(viewModel.status, MapLocationStatus.unavailable);
      expect(viewModel.position, isNull);
    });

    test('abre as configurações de localização e do app', () async {
      final service = _FakeLocationService();
      final viewModel = MapLocationViewModel(service);
      addTearDown(viewModel.dispose);

      await viewModel.openLocationSettings();
      await viewModel.openAppSettings();

      expect(service.openLocationSettingsCalled, isTrue);
      expect(service.openAppSettingsCalled, isTrue);
    });
  });
}
