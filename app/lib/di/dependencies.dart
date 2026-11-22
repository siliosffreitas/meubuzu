import '../data/config/api_config.dart';
import '../data/repositories/api_city_repository.dart';
import '../data/repositories/asset_place_search_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/details_bus_stop_repository.dart';
import '../data/repositories/details_line_repository.dart';
import '../data/repositories/favorites_repository.dart';
import '../data/repositories/tracking_repository.dart';
import '../data/repositories/user_location_repository.dart';
import '../data/services/api_bus_stop_service.dart';
import '../data/services/api_client.dart';
import '../data/services/api_favorites_service.dart';
import '../data/services/api_tracking_service.dart';
import '../data/services/api_line_search_service.dart';
import '../data/services/api_line_stops_service.dart';
import '../data/services/api_route_service.dart';
import '../data/services/bus_stop_service.dart';
import '../data/services/favorites_service.dart';
import '../data/services/line_search_service.dart';
import '../data/services/line_stops_service.dart';
import '../data/services/location_service.dart';
import '../data/services/route_service.dart';
import '../data/services/session_storage.dart';
import '../data/services/tracking_service.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/city_repository.dart';
import '../domain/repositories/details_bus_stop_repository.dart';
import '../domain/repositories/details_line_repository.dart';
import '../domain/repositories/favorites_repository.dart';
import '../domain/repositories/place_search_repository.dart';
import '../domain/repositories/tracking_repository.dart';
import '../domain/repositories/user_location_repository.dart';
import '../ui/features/auth/presentation/auth_code/auth_code_view_model.dart';
import '../ui/features/auth/presentation/auth_email/auth_email_view_model.dart';
import '../ui/features/bus_stop_details/presentation/details_bus_stop_view_model.dart';
import '../ui/features/city_selection/presentation/select_city_view_model.dart';
import '../ui/features/home/presentation/widgets/account/account_view_model.dart';
import '../ui/features/home/presentation/widgets/favorites/favorites_view_model.dart';
import '../ui/features/home/presentation/widgets/map/map_location_view_model.dart';
import '../ui/features/home/presentation/widgets/map/map_search_cache.dart';
import '../ui/features/home/presentation/widgets/map/map_search_view_model.dart';
import '../ui/features/home/presentation/widgets/map/map_tracking_view_model.dart';
import '../ui/features/line_details/presentation/details_line_view_model.dart';
import 'custom_injector.dart';

/// Injetor global da aplicação.
final injector = CustomInjector();

/// Registra services, repositórios e view models usados pelo app.
///
/// Deve ser chamado antes do `runApp`, em [main], para que as páginas possam
/// resolver suas dependências pelo [injector].
Future<void> setupDependencies() async {
  // ApiClient e AuthRepository são registrados antes dos services de catálogo,
  // que dependem da cidade selecionada e do token de acesso.
  injector.addService<ApiClient>(() => ApiClient(ApiConfig.baseUrl));
  injector.addService<SessionStorage>(SecureSessionStorage.new);
  injector.addRepository<AuthRepository>(
    () => ApiAuthRepository(
      injector.getService<ApiClient>(),
      injector.getService<SessionStorage>(),
    ),
  );

  injector.addService<LocationService>(DeviceLocationService.new);
  injector.addService<LineSearchService>(
    () => ApiLineSearchService(
      injector.getService<ApiClient>(),
      injector.getRepository<AuthRepository>(),
    ),
  );
  injector.addService<LineStopsService>(
    () => ApiLineStopsService(
      injector.getService<ApiClient>(),
      injector.getRepository<AuthRepository>(),
    ),
  );
  injector.addService<RouteService>(
    () => ApiRouteService(
      injector.getService<ApiClient>(),
      injector.getRepository<AuthRepository>(),
    ),
  );
  injector.addService<TrackingService>(
    () => ApiTrackingService(
      injector.getService<ApiClient>(),
      injector.getRepository<AuthRepository>(),
    ),
  );
  injector.addService<MapSearchCache>(MapSearchCache.new);
  injector.addService<BusStopService>(
    () => ApiBusStopService(
      injector.getService<ApiClient>(),
      injector.getRepository<AuthRepository>(),
    ),
  );
  injector.addRepository<CityRepository>(
    () => ApiCityRepository(
      injector.getService<ApiClient>(),
      injector.getRepository<AuthRepository>(),
    ),
  );
  injector.addRepository<PlaceSearchRepository>(
    () => AssetPlaceSearchRepository(
      lineSearchService: injector.getService<LineSearchService>(),
      busStopService: injector.getService<BusStopService>(),
    ),
  );
  injector.addRepository<DetailsLineRepository>(
    () => DetailsLineRepositoryImpl(
      injector.getService<LineSearchService>(),
      injector.getService<LineStopsService>(),
      injector.getService<BusStopService>(),
    ),
  );
  injector.addRepository<DetailsBusStopRepository>(
    () => DetailsBusStopRepositoryImpl(
      injector.getService<BusStopService>(),
      injector.getService<LineStopsService>(),
      injector.getService<LineSearchService>(),
    ),
  );
  injector.addRepository<UserLocationRepository>(
    () => DeviceUserLocationRepository(
      injector.getService<LocationService>(),
      injector.getService<BusStopService>(),
    ),
  );
  injector.addRepository<TrackingRepository>(
    () => TrackingRepositoryImpl(
      injector.getService<RouteService>(),
      injector.getService<LineSearchService>(),
      trackingService: injector.getService<TrackingService>(),
    ),
  );
  injector.addService<FavoritesService>(
    () => ApiFavoritesService(
      injector.getService<ApiClient>(),
      injector.getRepository<AuthRepository>(),
    ),
  );
  injector.addRepository<FavoritesRepository>(
    () => FavoritesRepositoryImpl(
      injector.getService<FavoritesService>(),
      injector.getRepository<AuthRepository>(),
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
  injector.addViewModelParam<SelectCityViewModel, bool>(
    (isChangeMode) => SelectCityViewModel(
      injector.getRepository<CityRepository>(),
      injector.getRepository<AuthRepository>(),
      isChangeMode: isChangeMode,
    ),
  );
  injector.addViewModel<AccountViewModel>(
    () => AccountViewModel(injector.getRepository<AuthRepository>()),
  );
  injector.addViewModel<FavoritesViewModel>(
    () => FavoritesViewModel(
      injector.getRepository<FavoritesRepository>(),
      injector.getRepository<AuthRepository>(),
    ),
  );
  injector.addViewModel<MapSearchViewModel>(
    () => MapSearchViewModel(
      injector.getRepository<PlaceSearchRepository>(),
      trackingRepository: injector.getRepository<TrackingRepository>(),
      favoritesRepository: injector.getRepository<FavoritesRepository>(),
      cache: injector.getService<MapSearchCache>(),
    ),
  );
  injector.addViewModel<MapLocationViewModel>(
    () =>
        MapLocationViewModel(injector.getRepository<UserLocationRepository>()),
  );
  injector.addViewModel<MapTrackingViewModel>(
    () => MapTrackingViewModel(injector.getRepository<TrackingRepository>()),
  );
  injector.addViewModelParam<DetailsLineViewModel, String>(
    (lineCode) => DetailsLineViewModel(
      injector.getRepository<DetailsLineRepository>(),
      lineCode: lineCode,
      trackingRepository: injector.getRepository<TrackingRepository>(),
      favoritesRepository: injector.getRepository<FavoritesRepository>(),
    ),
  );
  injector.addViewModelParam<DetailsBusStopViewModel, String>(
    (busStopCode) => DetailsBusStopViewModel(
      injector.getRepository<DetailsBusStopRepository>(),
      busStopCode: busStopCode,
      locationRepository: injector.getRepository<UserLocationRepository>(),
      trackingRepository: injector.getRepository<TrackingRepository>(),
      favoritesRepository: injector.getRepository<FavoritesRepository>(),
    ),
  );

  injector.commit();
}

/// Libera todos os recursos gerenciados pelo injetor.
void disposeDependencies() {
  injector.dispose();
}

/// Recria as dependências, descartando todo o estado em memória.
///
/// Não é chamado no logout: o `AuthRepository` é observado pelo GoRouter e
/// precisa continuar vivo para notificar a mudança de sessão.
Future<void> resetDependencies() async {
  injector.reset();
  await setupDependencies();
}
