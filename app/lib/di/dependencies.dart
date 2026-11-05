import '../data/repositories/asset_place_search_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/user_location_repository.dart';
import '../data/services/bus_stop_service.dart';
import '../data/services/line_search_service.dart';
import '../data/services/location_service.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/place_search_repository.dart';
import '../domain/repositories/user_location_repository.dart';
import '../ui/features/auth/presentation/auth_code/auth_code_view_model.dart';
import '../ui/features/auth/presentation/auth_email/auth_email_view_model.dart';
import '../ui/features/home/presentation/widgets/map/map_location_view_model.dart';
import '../ui/features/home/presentation/widgets/map/map_search_view_model.dart';
import 'custom_injector.dart';

/// Injetor global da aplicação.
final injector = CustomInjector();

/// Registra services, repositórios e view models usados pelo app.
///
/// Deve ser chamado antes do `runApp`, em [main], para que as páginas possam
/// resolver suas dependências pelo [injector].
Future<void> setupDependencies() async {
  injector.addService<LocationService>(DeviceLocationService.new);
  injector.addService<BusStopService>(AssetBusStopService.new);
  injector.addService<LineSearchService>(AssetLineSearchService.new);

  injector.addRepository<AuthRepository>(() => const FakeAuthRepository());
  injector.addRepository<PlaceSearchRepository>(
    () => AssetPlaceSearchRepository(),
  );
  injector.addRepository<UserLocationRepository>(
    () => DeviceUserLocationRepository(
      injector.getService<LocationService>(),
      injector.getService<BusStopService>(),
    ),
  );

  injector.addViewModel<AuthEmailViewModel>(
    () => AuthEmailViewModel(injector.getRepository<AuthRepository>()),
  );
  injector.addViewModelParam<AuthCodeViewModel, String>(
    (email) => AuthCodeViewModel(
      injector.getRepository<AuthRepository>(),
      email: email,
    ),
  );
  injector.addViewModel<MapSearchViewModel>(
    () => MapSearchViewModel(injector.getRepository<PlaceSearchRepository>()),
  );
  injector.addViewModel<MapLocationViewModel>(
    () =>
        MapLocationViewModel(injector.getRepository<UserLocationRepository>()),
  );

  injector.commit();
}

/// Libera todos os recursos gerenciados pelo injetor.
void disposeDependencies() {
  injector.dispose();
}

/// Recria as dependências, descartando o estado da sessão atual.
///
/// Deve ser chamado no logout para que a próxima sessão use instâncias novas.
Future<void> resetDependencies() async {
  injector.reset();
  await setupDependencies();
}
