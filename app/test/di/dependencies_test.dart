import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/data/repositories/auth_repository.dart';
import 'package:meubuzu/data/repositories/place_search_repository.dart';
import 'package:meubuzu/data/repositories/user_location_repository.dart';
import 'package:meubuzu/data/services/location_service.dart';
import 'package:meubuzu/di/dependencies.dart';
import 'package:meubuzu/domain/repositories/auth_repository.dart';
import 'package:meubuzu/domain/repositories/place_search_repository.dart';
import 'package:meubuzu/domain/repositories/user_location_repository.dart';
import 'package:meubuzu/ui/features/auth/presentation/auth_code/auth_code_view_model.dart';
import 'package:meubuzu/ui/features/auth/presentation/auth_email/auth_email_view_model.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_location_view_model.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_search_view_model.dart';

void main() {
  tearDown(injector.reset);

  test('registra e resolve services, repositórios e view models', () async {
    await setupDependencies();

    expect(injector.isReady, isTrue);
    expect(
      injector.getService<LocationService>(),
      isA<DeviceLocationService>(),
    );
    expect(injector.getRepository<AuthRepository>(), isA<FakeAuthRepository>());
    expect(
      injector.getRepository<PlaceSearchRepository>(),
      isA<FakePlaceSearchRepository>(),
    );
    expect(
      injector.getRepository<UserLocationRepository>(),
      isA<DeviceUserLocationRepository>(),
    );

    final emailViewModel = injector.getViewModel<AuthEmailViewModel>();
    final codeViewModel = injector.getViewModelParam<AuthCodeViewModel, String>(
      'ana@exemplo.com',
    );
    final searchViewModel = injector.getViewModel<MapSearchViewModel>();
    final locationViewModel = injector.getViewModel<MapLocationViewModel>();

    expect(emailViewModel, isA<AuthEmailViewModel>());
    expect(codeViewModel.email, 'ana@exemplo.com');
    expect(searchViewModel, isA<MapSearchViewModel>());
    expect(locationViewModel, isA<MapLocationViewModel>());

    emailViewModel.dispose();
    codeViewModel.dispose();
    searchViewModel.dispose();
    locationViewModel.dispose();
  });

  test('reset descarta as dependências registradas', () async {
    await setupDependencies();
    expect(injector.isReady, isTrue);

    injector.reset();

    expect(injector.isReady, isFalse);
  });
}
