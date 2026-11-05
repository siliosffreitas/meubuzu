import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../data/place_search_repository.dart';
import 'map_search_view_model.dart';
import 'map_style.dart';
import 'widgets/map_search_bar.dart';
import 'widgets/search_results_panel.dart';

/// Aba principal com o mapa e a busca de linhas e paradas.
class MapTab extends StatefulWidget {
  const MapTab({
    super.key,
    this.searchRepository = const FakePlaceSearchRepository(),
  });

  final PlaceSearchRepository searchRepository;

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  static const _initialTarget = LatLng(-23.5505, -46.6333);

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  late final MapSearchViewModel _searchViewModel;
  final _markers = <Marker>{};

  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _searchViewModel = MapSearchViewModel(widget.searchRepository);
    _searchFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _searchFocusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _searchController.dispose();
    _searchViewModel.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    _searchViewModel.setFocused(_searchFocusNode.hasFocus);
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    final target = LatLng(suggestion.latitude, suggestion.longitude);

    _searchController.text = suggestion.title;
    _searchViewModel.setQuery(suggestion.title);
    _searchFocusNode.unfocus();

    setState(() {
      _markers
        ..clear()
        ..add(
          Marker(
            markerId: MarkerId(suggestion.id),
            position: target,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            infoWindow: InfoWindow(
              title: suggestion.title,
              snippet: suggestion.subtitle,
            ),
          ),
        );
    });

    await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 15));

    if (!mounted) {
      return;
    }

    final message = suggestion.type == PlaceSuggestionType.line
        ? 'Acompanhamento da linha ${suggestion.title} em breve.'
        : 'Parada ${suggestion.title} exibida no mapa.';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: _initialTarget,
            zoom: 13.2,
          ),
          style: kMapStyle,
          markers: _markers,
          onMapCreated: (controller) => _mapController = controller,
          onTap: (_) => _searchFocusNode.unfocus(),
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          myLocationButtonEnabled: false,
          myLocationEnabled: false,
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MapSearchBar(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _searchViewModel.setQuery,
                    onClear: _searchViewModel.clear,
                  ),
                  AnimatedBuilder(
                    animation: _searchViewModel,
                    builder: (context, _) {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) {
                          return SizeTransition(
                            sizeFactor: animation,
                            alignment: Alignment.topCenter,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: _searchViewModel.showsResults
                            ? Padding(
                                key: const ValueKey('search-results'),
                                padding: const EdgeInsets.only(top: 10),
                                child: SearchResultsPanel(
                                  query: _searchViewModel.query.trim(),
                                  isLoading: _searchViewModel.isLoading,
                                  results: _searchViewModel.results,
                                  onSelected: _selectSuggestion,
                                ),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('search-idle'),
                              ),
                      );
                    },
                  ),
                ],
              ),
            ),
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
