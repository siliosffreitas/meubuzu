import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../../data/models/user_coordinates.dart';
import '../../../../../../data/repositories/user_location_repository.dart';
import '../../../../../../data/services/location_service.dart';
import '../../../../../../di/dependencies.dart';
import '../../../../../../domain/repositories/user_location_repository.dart';
import 'map_location_state.dart';
import 'map_location_view_model.dart';
import 'map_style.dart';
import 'widgets/location_notice_card.dart';

/// Aba principal com o mapa e a localização do usuário.
///
/// A busca de linhas e paradas será adicionada posteriormente.
class MapTab extends StatefulWidget {
  const MapTab({super.key, this.locationRepository});

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
  bool _centeredOnUser = false;
  bool _ownsLocationRepository = false;

  @override
  void initState() {
    super.initState();

    final hasOverrides = widget.locationRepository != null;
    final useInjector = injector.isReady && !hasOverrides;

    if (useInjector) {
      _locationRepository = injector.getRepository<UserLocationRepository>();
      _locationViewModel = injector.getViewModel<MapLocationViewModel>();
    } else {
      _locationRepository =
          widget.locationRepository ??
          DeviceUserLocationRepository(const DeviceLocationService());
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

  @override
  Widget build(BuildContext context) {
    final locationState = _locationViewModel.state;
    final isLocationReady = _locationViewModel.isReady;

    return Stack(
      fit: StackFit.expand,
      children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: _initialTarget,
            zoom: _initialZoom,
          ),
          style: kMapStyle,
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
