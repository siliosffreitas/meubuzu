import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/data/repositories/api_city_repository.dart';
import 'package:meubuzu/data/repositories/asset_place_search_repository.dart';
import 'package:meubuzu/data/repositories/auth_repository.dart';
import 'package:meubuzu/data/repositories/details_line_repository.dart';
import 'package:meubuzu/data/repositories/user_location_repository.dart';
import 'package:meubuzu/data/services/api_bus_stop_service.dart';
import 'package:meubuzu/data/services/bus_stop_service.dart';
import 'package:meubuzu/data/services/line_search_service.dart';
import 'package:meubuzu/data/services/line_stops_service.dart';
import 'package:meubuzu/data/services/location_service.dart';
import 'package:meubuzu/di/dependencies.dart';
import 'package:meubuzu/domain/repositories/auth_repository.dart';
import 'package:meubuzu/domain/repositories/city_repository.dart';
import 'package:meubuzu/domain/repositories/details_line_repository.dart';
import 'package:meubuzu/domain/repositories/place_search_repository.dart';
import 'package:meubuzu/domain/repositories/user_location_repository.dart';
import 'package:meubuzu/ui/features/auth/presentation/auth_code/auth_code_view_model.dart';
import 'package:meubuzu/ui/features/auth/presentation/auth_email/auth_email_view_model.dart';
import 'package:meubuzu/ui/features/city_selection/presentation/select_city_view_model.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_location_view_model.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_search_cache.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_search_view_model.dart';
import 'package:meubuzu/ui/features/line_details/presentation/details_line_view_model.dart';

void main() {
  tearDown(injector.reset);

  test('registra e resolve services, repositórios e view models', () async {
    await setupDependencies();

    expect(injector.isReady, isTrue);
    expect(
      injector.getService<LocationService>(),
      isA<DeviceLocationService>(),
    );
    expect(injector.getService<BusStopService>(), isA<ApiBusStopService>());
    expect(
      injector.getService<LineSearchService>(),
      isA<AssetLineSearchService>(),
    );
    expect(
      injector.getService<LineStopsService>(),
      isA<AssetLineStopsService>(),
    );
    final searchCache = injector.getService<MapSearchCache>();
    expect(searchCache, isA<MapSearchCache>());
    expect(injector.getService<MapSearchCache>(), same(searchCache));
    expect(injector.getRepository<AuthRepository>(), isA<ApiAuthRepository>());
    expect(injector.getRepository<CityRepository>(), isA<ApiCityRepository>());
    expect(
      injector.getRepository<PlaceSearchRepository>(),
      isA<AssetPlaceSearchRepository>(),
    );
    expect(
      injector.getRepository<DetailsLineRepository>(),
      isA<DetailsLineRepositoryImpl>(),
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
    final detailsLineViewModel = injector
        .getViewModelParam<DetailsLineViewModel, String>('0301');
    final selectCityViewModel = injector
        .getViewModelParam<SelectCityViewModel, bool>(true);

    expect(emailViewModel, isA<AuthEmailViewModel>());
    expect(codeViewModel.email, 'ana@exemplo.com');
    expect(searchViewModel, isA<MapSearchViewModel>());
    expect(locationViewModel, isA<MapLocationViewModel>());
    expect(detailsLineViewModel, isA<DetailsLineViewModel>());
    expect(detailsLineViewModel.lineCode, '0301');
    expect(selectCityViewModel, isA<SelectCityViewModel>());
    expect(selectCityViewModel.isChangeMode, isTrue);

    emailViewModel.dispose();
    codeViewModel.dispose();
    searchViewModel.dispose();
    locationViewModel.dispose();
    detailsLineViewModel.dispose();
    selectCityViewModel.dispose();
  });

  test('reset descarta as dependências registradas', () async {
    await setupDependencies();
    expect(injector.isReady, isTrue);

    injector.reset();

    expect(injector.isReady, isFalse);
  });
}
