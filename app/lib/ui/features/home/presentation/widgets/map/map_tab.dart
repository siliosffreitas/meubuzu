import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../../data/models/place_suggestion.dart';
import '../../../../../../domain/models/user_coordinates.dart';
import '../../../../../../data/repositories/user_location_repository.dart';
import '../../../../../../data/services/bus_stop_service.dart';
import '../../../../../../data/services/location_service.dart';
import '../../../../../../di/dependencies.dart';
import '../../../../../../domain/repositories/place_search_repository.dart';
import '../../../../../../domain/repositories/user_location_repository.dart';
import '../../../../../routing/app_routes.dart';
import 'map_location_state.dart';
import 'map_location_view_model.dart';
import 'map_search_arguments.dart';
import 'map_style.dart';
import 'nearby_stop_markers.dart';
import 'widgets/location_notice_card.dart';
import 'widgets/map_search_bar.dart';

/// Aba principal com o mapa, a busca e a localização do usuário.
class MapTab extends StatefulWidget {
  const MapTab({super.key, this.searchRepository, this.locationRepository});

  /// Permite injetar um repositório de busca fake em testes.
  final PlaceSearchRepository? searchRepository;

  /// Permite injetar um repositório fake em testes. Quando não informado, o
  /// mapa usa o repositório registrado no injetor.
  final UserLocationRepository? locationRepository;

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> with WidgetsBindingObserver {
  static const _initialTarget = LatLng(-23.5505, -46.6333);
  static const _initialZoom = 13.2;
  static const _userZoom = 16.0;

  late final UserLocationRepository _locationRepository;
  late final MapLocationViewModel _locationViewModel;

  GoogleMapController? _mapController;
  Marker? _selectedMarker;
  PlaceSuggestion? _selectedSuggestion;
  bool _centeredOnUser = false;
  bool _ownsLocationRepository = false;

  @override
  void initState() {
    super.initState();

    final hasOverrides =
        widget.searchRepository != null || widget.locationRepository != null;
    final useInjector = injector.isReady && !hasOverrides;

    if (useInjector) {
      _locationRepository = injector.getRepository<UserLocationRepository>();
      _locationViewModel = injector.getViewModel<MapLocationViewModel>();
    } else {
      _locationRepository =
          widget.locationRepository ??
          DeviceUserLocationRepository(
            const DeviceLocationService(),
            AssetBusStopService(),
          );
      _ownsLocationRepository = widget.locationRepository == null;
      _locationViewModel = MapLocationViewModel(_locationRepository);
    }

    _locationViewModel.addListener(_handleLocationChange);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _locationViewModel.initialize();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationViewModel
      ..removeListener(_handleLocationChange)
      ..dispose();
    if (_ownsLocationRepository) {
      _locationRepository.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    // Ao voltar das configurações, revalida o estado sem abrir novamente o
    // diálogo de permissão. Se o GPS estava desligado, tenta a sequência
    // completa para pedir a permissão assim que ele estiver ligado.
    switch (_locationViewModel.state) {
      case MapLocationServiceDisabled():
        _locationViewModel.initialize();
      case MapLocationPermissionDenied():
      case MapLocationPermissionDeniedForever():
        _locationViewModel.initialize(requestPermission: false);
      default:
        break;
    }
  }

  Future<void> _openSearch() async {
    final activeSuggestion = _selectedSuggestion;
    final suggestion = await context.pushNamed<PlaceSuggestion>(
      AppRoutes.mapSearchName,
      extra: MapSearchPageArguments(
        repository: widget.searchRepository,
        activeSuggestionId: activeSuggestion?.type == PlaceSuggestionType.line
            ? activeSuggestion!.id
            : null,
      ),
    );

    if (!mounted || suggestion == null) {
      return;
    }

    await _selectSuggestion(suggestion);
  }

  void _handleLocationChange() {
    if (!mounted) {
      return;
    }
    setState(() {});

    final position = _locationViewModel.position;
    if (position != null && !_centeredOnUser) {
      _centeredOnUser = true;
      _moveToUser(position);
    }
  }

  Future<void> _moveToUser(UserCoordinates position) async {
    final target = LatLng(position.latitude, position.longitude);
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(target, _userZoom),
    );
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    final target = LatLng(
      suggestion.latitude ?? _initialTarget.latitude,
      suggestion.longitude ?? _initialTarget.longitude,
    );

    setState(() {
      _selectedSuggestion = suggestion;
      _selectedMarker = Marker(
        markerId: MarkerId('search-${suggestion.id}'),
        position: target,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: suggestion.title,
          snippet: suggestion.subtitle,
        ),
      );
    });

    await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 15));

    if (!mounted) {
      return;
    }

    if (suggestion.type == PlaceSuggestionType.line) {
      await context.pushNamed(
        AppRoutes.detailsLineName,
        pathParameters: {'code': suggestion.code},
      );
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Parada ${suggestion.title} exibida no mapa.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final locationState = _locationViewModel.state;
    final isLocationReady = _locationViewModel.isReady;
    final markers = <Marker>{
      ...buildNearbyStopMarkers(locationState.nearbyStops),
      ?_selectedMarker,
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: _initialTarget,
            zoom: _initialZoom,
          ),
          style: kMapStyle,
          markers: markers,
          onMapCreated: (controller) {
            _mapController = controller;
            final position = _locationViewModel.position;
            if (position != null) {
              _mapController?.moveCamera(
                CameraUpdate.newLatLngZoom(
                  LatLng(position.latitude, position.longitude),
                  _userZoom,
                ),
              );
            }
          },
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          myLocationButtonEnabled: false,
          myLocationEnabled: isLocationReady,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: MapSearchBar(
                text: _selectedSuggestion == null
                    ? null
                    : _selectedSuggestion!.type == PlaceSuggestionType.line
                    ? _selectedSuggestion!.code
                    : _selectedSuggestion!.title,
                onTap: _openSearch,
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: LocationNoticeCard(
            state: locationState,
            onOpenLocationSettings: _locationViewModel.openLocationSettings,
            onRequestPermission: _locationViewModel.initialize,
            onOpenAppSettings: _locationViewModel.openAppSettings,
            onRetry: _locationViewModel.initialize,
          ),
        ),
        if (isLocationReady)
          Positioned(
            right: 16,
            bottom: 16,
            child: _MapControlButton(
              tooltip: 'Centralizar na minha localização',
              icon: Icons.my_location_rounded,
              onPressed: () {
                final position = _locationViewModel.position;
                if (position != null) {
                  _moveToUser(position);
                }
              },
            ),
          ),
        // Evita que a barra de status escura deixe o mapa sem contraste no topo.
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 1,
          child: ColoredBox(color: AppColors.background),
        ),
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: const Color(0x242E3C3E),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: 22, color: AppColors.primary),
      ),
    );
  }
}
