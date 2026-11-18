import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../../core/extensions/line_map_color.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../../data/models/place_suggestion.dart';
import '../../../../../../data/repositories/tracking_repository.dart';
import '../../../../../../data/services/line_search_service.dart';
import '../../../../../../data/services/route_service.dart';
import '../../../../../../domain/models/user_coordinates.dart';
import '../../../../../../data/repositories/user_location_repository.dart';
import '../../../../../../data/services/bus_stop_service.dart';
import '../../../../../../data/services/location_service.dart';
import '../../../../../../data/services/tracking_service.dart';
import '../../../../../../di/dependencies.dart';
import '../../../../../../domain/models/bus_stop.dart';
import '../../../../../../domain/models/tracked_line.dart';
import '../../../../../../domain/repositories/place_search_repository.dart';
import '../../../../../../domain/repositories/tracking_repository.dart';
import '../../../../../../domain/repositories/user_location_repository.dart';
import '../../../../../../domain/repositories/auth_repository.dart';
import '../../../../../routing/app_routes.dart';
import 'map_location_state.dart';
import 'map_location_view_model.dart';
import 'map_search_arguments.dart';
import 'map_style.dart';
import 'map_tracking_animations.dart';
import 'map_tracking_camera.dart';
import 'map_tracking_directions.dart';
import 'map_tracking_markers.dart';
import 'map_tracking_polylines.dart';
import 'map_tracking_view_model.dart';
import 'nearby_stop_markers.dart';
import 'widgets/location_notice_card.dart';
import 'widgets/map_search_bar.dart';
import 'widgets/tracking_panel.dart';

/// Aba principal com o mapa, a busca e a localização do usuário.
class MapTab extends StatefulWidget {
  const MapTab({
    super.key,
    this.searchRepository,
    this.locationRepository,
    this.trackingRepository,
    this.trackingViewModel,
  });

  /// Permite injetar um repositório de busca fake em testes.
  final PlaceSearchRepository? searchRepository;

  /// Permite injetar um repositório fake em testes. Quando não informado, o
  /// mapa usa o repositório registrado no injetor.
  final UserLocationRepository? locationRepository;

  /// Permite injetar um repositório de rastreamento fake em testes.
  final TrackingRepository? trackingRepository;

  /// Permite injetar um view model de rastreamento pronto em testes.
  final MapTrackingViewModel? trackingViewModel;

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _fallbackTarget = LatLng(-5.16, -42.79);
  static const _initialZoom = 13.2;
  static const _userZoom = 16.0;
  static const _routePadding = 48.0;

  late final UserLocationRepository _locationRepository;
  late final MapLocationViewModel _locationViewModel;
  late final MapTrackingViewModel _trackingViewModel;
  AuthRepository? _authRepository;
  String? _citySlug;

  /// Centro inicial do mapa: a cidade selecionada ou Teresina como fallback.
  LatLng get _initialTarget {
    final city = _authRepository?.selectedCity;
    if (city == null) {
      return _fallbackTarget;
    }
    return LatLng(city.latitude, city.longitude);
  }

  final Set<String> _fittedLineCodes = <String>{};
  Set<String> _trackedLineKeys = <String>{};
  final TrackingBusMarkerIcons _busIcons = TrackingBusMarkerIcons();
  final NearbyStopMarkerIcons _stopIcons = NearbyStopMarkerIcons();
  final TrackingBusDirections _busDirections = TrackingBusDirections();
  late final TrackingBusAnimator _busAnimator;

  GoogleMapController? _mapController;
  Marker? _selectedMarker;
  PlaceSuggestion? _selectedSuggestion;
  bool _centeredOnUser = false;
  bool _ownsLocationRepository = false;

  @override
  void initState() {
    super.initState();

    final hasOverrides =
        widget.searchRepository != null ||
        widget.locationRepository != null ||
        widget.trackingRepository != null ||
        widget.trackingViewModel != null;
    final useInjector = injector.isReady && !hasOverrides;

    if (useInjector) {
      _locationRepository = injector.getRepository<UserLocationRepository>();
      _locationViewModel = injector.getViewModel<MapLocationViewModel>();
      _trackingViewModel = injector.getViewModel<MapTrackingViewModel>();
      _authRepository = injector.getRepository<AuthRepository>();
      _citySlug = _authRepository?.selectedCity?.slug;
      _authRepository?.addListener(_handleCityChange);
    } else {
      _locationRepository =
          widget.locationRepository ??
          DeviceUserLocationRepository(
            const DeviceLocationService(),
            AssetBusStopService(),
          );
      _ownsLocationRepository = widget.locationRepository == null;
      _locationViewModel = MapLocationViewModel(_locationRepository);
      _trackingViewModel =
          widget.trackingViewModel ??
          MapTrackingViewModel(
            widget.trackingRepository ??
                TrackingRepositoryImpl(
                  // Em produção o injetor sempre está pronto e os services vêm
                  // da API. O fallback de assets existe apenas para testes que
                  // renderizam a aba sem inicializar as dependências.
                  injector.isReady
                      ? injector.getService<RouteService>()
                      : AssetRouteService(),
                  injector.isReady
                      ? injector.getService<LineSearchService>()
                      : AssetLineSearchService(),
                  trackingService: const EmptyTrackingService(),
                ),
          );
    }

    _busAnimator = TrackingBusAnimator(vsync: this)
      ..addListener(_handleBusAnimation);

    _locationViewModel.addListener(_handleLocationChange);
    _trackingViewModel.addListener(_handleTrackingChange);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _locationViewModel.initialize();
        _trackedLineKeys = {
          for (final tracked in _trackingViewModel.trackedLines)
            trackedLineKey(tracked),
        };
        _busDirections.update(_trackingViewModel.trackedLines);
        _busAnimator.jumpTo(_trackedBusPositions());
        _ensureBusIcons();
        _ensureStopIcons(_locationViewModel.visibleStops);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authRepository?.removeListener(_handleCityChange);
    _busAnimator
      ..removeListener(_handleBusAnimation)
      ..dispose();
    _locationViewModel
      ..removeListener(_handleLocationChange)
      ..dispose();
    _trackingViewModel
      ..removeListener(_handleTrackingChange)
      ..dispose();
    if (_ownsLocationRepository) {
      _locationRepository.dispose();
    }
    super.dispose();
  }

  void _handleCityChange() {
    if (!mounted) {
      return;
    }

    final nextSlug = _authRepository?.selectedCity?.slug;
    if (nextSlug == _citySlug) {
      return;
    }

    _citySlug = nextSlug;
    _centeredOnUser = false;
    _stopTrackingForCityChange();

    final controller = _mapController;
    if (controller == null) {
      return;
    }
    controller.animateCamera(
      CameraUpdate.newLatLngZoom(_initialTarget, _initialZoom),
    );
  }

  /// Encerra o rastreamento e limpa a seleção ao trocar de cidade.
  ///
  /// As linhas e posições pertencem à cidade anterior; manter o rastreamento
  /// mostraria ônibus de outra cidade no mapa.
  void _stopTrackingForCityChange() {
    final trackedLines = List<TrackedLine>.of(_trackingViewModel.trackedLines);
    for (final tracked in trackedLines) {
      final boardingCode = tracked.line.boardingCode?.trim();
      final code = boardingCode != null && boardingCode.isNotEmpty
          ? boardingCode
          : tracked.line.id.trim();
      if (code.isEmpty) {
        continue;
      }
      unawaited(_trackingViewModel.stopTracking(code));
    }

    _fittedLineCodes.clear();
    if (_selectedSuggestion == null && _selectedMarker == null) {
      return;
    }
    setState(() {
      _selectedSuggestion = null;
      _selectedMarker = null;
    });
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
        trackingRepository: widget.trackingRepository,
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

    _ensureStopIcons(_locationViewModel.visibleStops);

    final position = _locationViewModel.position;
    if (position != null && !_centeredOnUser) {
      _centeredOnUser = true;
      _moveToUser(position);
    }
  }

  void _handleTrackingChange() {
    if (!mounted) {
      return;
    }

    final trackedLines = _trackingViewModel.trackedLines;
    final currentKeys = {
      for (final tracked in trackedLines) trackedLineKey(tracked),
    };
    final removedKeys = _trackedLineKeys.difference(currentKeys);
    _trackedLineKeys = currentKeys;

    _busDirections.update(trackedLines);
    _busAnimator.animateTo(_trackedBusPositions());
    _pruneFittedLines();
    setState(() {});
    if (removedKeys.isNotEmpty) {
      _fitAfterRemoval(trackedLines);
    } else {
      _fitLatestRoute();
    }
    _ensureBusIcons();
  }

  /// Reposiciona a câmera depois que uma linha sai do mapa.
  ///
  /// Sem linhas restantes, mostra o usuário e as paradas próximas. Se ainda
  /// houver linhas, enquadra o traçado de todas as que permaneceram.
  void _fitAfterRemoval(List<TrackedLine> trackedLines) {
    if (trackedLines.isEmpty) {
      final position = _locationViewModel.position;
      if (position == null) {
        return;
      }
      _fitPositions(
        userAndVisibleStopsCoordinates(
          position: position,
          visibleStops: _locationViewModel.visibleStops,
        ),
      );
      return;
    }

    _fitPositions(trackedLinesCoordinates(trackedLines));
  }

  /// Descarta enquadramentos de linhas que saíram do mapa.
  void _pruneFittedLines() {
    final trackedKeys = {
      for (final tracked in _trackingViewModel.trackedLines)
        trackedLineKey(tracked),
    };
    _fittedLineCodes.retainWhere(trackedKeys.contains);
  }

  /// Reposiciona os marcadores a cada quadro da animação.
  void _handleBusAnimation() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  /// Posições finais dos ônibus, por `linha:ônibus`.
  Map<String, LatLng> _trackedBusPositions() {
    return {
      for (final tracked in _trackingViewModel.trackedLines)
        for (final position in tracked.busPositions)
          trackedBusKey(tracked, position): LatLng(
            position.latitude,
            position.longitude,
          ),
    };
  }

  /// Gera os ícones dos ônibus com a cor exata de cada linha acompanhada.
  Future<void> _ensureBusIcons() async {
    final colors = [
      for (final tracked in _trackingViewModel.trackedLines)
        if (tracked.busPositions.isNotEmpty) tracked.line.mapColor,
    ];
    if (colors.isEmpty) {
      return;
    }

    final created = await _busIcons.ensure(colors);
    if (created && mounted) {
      setState(() {});
    }
  }

  /// Gera os ícones (anel + nome) das paradas próximas.
  Future<void> _ensureStopIcons(Iterable<BusStop> stops) async {
    final created = await _stopIcons.ensure(stops.map((stop) => stop.name));
    if (created && mounted) {
      setState(() {});
    }
  }

  Future<void> _moveToUser(UserCoordinates position) async {
    final target = LatLng(position.latitude, position.longitude);
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(target, _userZoom),
    );
  }

  /// Consulta as paradas da área visível sempre que a câmera para de mover.
  ///
  /// O zoom é repassado ao view model, que limpa os marcadores quando o mapa
  /// está afastado demais para exibi-los.
  Future<void> _syncVisibleStops() async {
    final controller = _mapController;
    if (controller == null || !mounted) {
      return;
    }

    try {
      final zoom = await controller.getZoomLevel();
      final region = await controller.getVisibleRegion();
      if (!mounted) {
        return;
      }
      await _locationViewModel.updateVisibleArea(
        southwest: UserCoordinates(
          latitude: region.southwest.latitude,
          longitude: region.southwest.longitude,
        ),
        northeast: UserCoordinates(
          latitude: region.northeast.latitude,
          longitude: region.northeast.longitude,
        ),
        zoom: zoom,
      );
    } catch (_) {
      // Sem a área visível, o mapa mantém as paradas já carregadas.
    }
  }

  /// Ajusta a câmera para a rota mais recente ainda não enquadrada.
  void _fitLatestRoute() {
    for (final tracked in _trackingViewModel.trackedLines.reversed) {
      final positions = tracked.route?.positions;
      if (positions == null || positions.isEmpty) {
        continue;
      }
      if (!_fittedLineCodes.add(trackedLineKey(tracked))) {
        continue;
      }
      _fitPositions(positions);
      return;
    }
  }

  void _fitPositions(List<UserCoordinates> positions) {
    final controller = _mapController;
    if (controller == null || positions.isEmpty) {
      return;
    }

    var minLatitude = positions.first.latitude;
    var maxLatitude = positions.first.latitude;
    var minLongitude = positions.first.longitude;
    var maxLongitude = positions.first.longitude;

    for (final position in positions.skip(1)) {
      if (position.latitude < minLatitude) {
        minLatitude = position.latitude;
      }
      if (position.latitude > maxLatitude) {
        maxLatitude = position.latitude;
      }
      if (position.longitude < minLongitude) {
        minLongitude = position.longitude;
      }
      if (position.longitude > maxLongitude) {
        maxLongitude = position.longitude;
      }
    }

    if (minLatitude == maxLatitude && minLongitude == maxLongitude) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(minLatitude, minLongitude),
          _userZoom,
        ),
      );
      return;
    }

    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLatitude, minLongitude),
          northeast: LatLng(maxLatitude, maxLongitude),
        ),
        _routePadding,
      ),
    );
  }

  /// Abre os detalhes de uma linha que já está no mapa.
  ///
  /// Usa o código de embarque exibido e, quando ele não existe, o código
  /// interno da linha. Ao remover a linha pela tela de detalhes, o painel é
  /// atualizado pelo próprio stream de rastreamento.
  Future<void> _openTrackedLineDetails(TrackedLine tracked) async {
    final code = _trackingCode(tracked);
    if (code.isEmpty) {
      return;
    }

    final removed = await context.pushNamed<bool>(
      AppRoutes.detailsLineName,
      pathParameters: {'code': code},
    );
    if (!mounted || removed != false) {
      return;
    }
    if (_selectedSuggestion?.code == code) {
      setState(() => _selectedSuggestion = null);
    }
  }

  /// Código de rastreamento (`sgLinha`) da linha, com fallback para o interno.
  String _trackingCode(TrackedLine tracked) {
    final boardingCode = tracked.line.boardingCode?.trim();
    return boardingCode != null && boardingCode.isNotEmpty
        ? boardingCode
        : tracked.line.id.trim();
  }

  /// Encerra o rastreamento da linha removida pelo gesto no painel.
  void _removeTrackedLine(TrackedLine tracked) {
    final code = _trackingCode(tracked);
    if (code.isEmpty) {
      return;
    }
    unawaited(_trackingViewModel.stopTracking(code));
    if (_selectedSuggestion?.code == code) {
      setState(() => _selectedSuggestion = null);
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    // Linhas abrem os detalhes primeiro. O rastreamento só começa quando o
    // usuário confirma no botão principal da tela de detalhes.
    if (suggestion.type == PlaceSuggestionType.line) {
      final started = await context.pushNamed<bool>(
        AppRoutes.detailsLineName,
        pathParameters: {'code': suggestion.code},
      );
      if (!mounted) {
        return;
      }
      // A tela de detalhes devolve `false` depois de remover a linha do mapa.
      if (started == false) {
        if (_selectedSuggestion?.code == suggestion.code) {
          setState(() => _selectedSuggestion = null);
        }
        return;
      }
      if (started != true) {
        return;
      }
    } else {
      await _openBusStopDetails(suggestion.code);
      return;
    }

    await _startTracking(suggestion);
  }

  /// Abre os detalhes de uma parada pelo código do catálogo.
  Future<void> _openBusStopDetails(String busStopCode) async {
    final code = busStopCode.trim();
    if (code.isEmpty) {
      return;
    }
    await context.pushNamed<void>(
      AppRoutes.detailsBusStopName,
      pathParameters: {'code': code},
    );
  }

  void _handleNearbyStopTap(BusStop stop) {
    _openBusStopDetails(stop.code);
  }

  Future<void> _startTracking(PlaceSuggestion suggestion) async {
    if (suggestion.type == PlaceSuggestionType.line) {
      setState(() {
        _selectedSuggestion = suggestion;
        _selectedMarker = null;
      });

      // O view model adiciona a linha ao repositório de rastreamento e expõe
      // o traçado carregado para o mapa desenhar a polyline. O sucesso é
      // silencioso; só erros geram aviso para o usuário.
      final success = await _trackingViewModel.startTracking(suggestion.code);
      if (!mounted || success) {
        return;
      }

      _showMessage(
        _trackingViewModel.state.errorMessage ??
            'Não foi possível carregar a rota da linha ${suggestion.code}.',
      );
      return;
    }

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

    _showMessage('Parada ${suggestion.title} exibida no mapa.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final locationState = _locationViewModel.state;
    final isLocationReady = _locationViewModel.isReady;
    final trackedLines = _trackingViewModel.trackedLines;
    final hasTrackedLines = trackedLines.isNotEmpty;
    final markers = <Marker>{
      ...buildNearbyStopMarkers(
        _locationViewModel.visibleStops,
        iconFor: (stop) => _stopIcons.iconFor(stop.name),
        anchorFor: (stop) => _stopIcons.anchorFor(stop.name),
        onTap: _handleNearbyStopTap,
      ),
      ...buildTrackingBusMarkers(
        trackedLines,
        positions: _busAnimator.positions,
        bearings: _busDirections.bearings,
        iconFor: (color) => _busIcons[color],
        arrowIconFor: (color) => _busIcons.arrow(color),
      ),
      ?_selectedMarker,
    };
    final polylines = buildTrackingPolylines(trackedLines);

    return Stack(
      fit: StackFit.expand,
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _initialTarget,
            zoom: _initialZoom,
          ),
          style: kMapStyle,
          markers: markers,
          polylines: polylines,
          onMapCreated: (controller) {
            _mapController = controller;
            if (_trackingViewModel.state.hasRoutes) {
              _fittedLineCodes.clear();
              _fitLatestRoute();
            } else {
              final position = _locationViewModel.position;
              if (position != null) {
                _mapController?.moveCamera(
                  CameraUpdate.newLatLngZoom(
                    LatLng(position.latitude, position.longitude),
                    _userZoom,
                  ),
                );
              }
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _syncVisibleStops();
              }
            });
          },
          onCameraIdle: _syncVisibleStops,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasLocationNotice(locationState)) ...[
                LocationNoticeCard(
                  state: locationState,
                  onOpenLocationSettings:
                      _locationViewModel.openLocationSettings,
                  onRequestPermission: _locationViewModel.initialize,
                  onOpenAppSettings: _locationViewModel.openAppSettings,
                  onRetry: _locationViewModel.initialize,
                ),
                const SizedBox(height: 12),
              ],
              if (isLocationReady)
                Align(
                  alignment: Alignment.centerRight,
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
              if (isLocationReady && hasTrackedLines)
                const SizedBox(height: 12),
              if (hasTrackedLines)
                TrackingPanel(
                  trackedLines: trackedLines,
                  updatedAt: _trackingViewModel.updatedAt,
                  onLineTap: _openTrackedLineDetails,
                  onRemoveLine: _removeTrackedLine,
                ),
            ],
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
