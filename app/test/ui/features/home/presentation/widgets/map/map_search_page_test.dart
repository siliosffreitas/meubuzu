import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meubuzu/data/models/place_suggestion.dart';
import 'package:meubuzu/domain/models/city.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/domain/models/tracked_line.dart';
import 'package:meubuzu/domain/repositories/auth_repository.dart';
import 'package:meubuzu/domain/repositories/place_search_repository.dart';
import 'package:meubuzu/domain/repositories/tracking_repository.dart';
import 'package:meubuzu/ui/core/theme/app_theme.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_search_cache.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_search_page.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_search_view_model.dart';

import '../../../../../../helpers/fake_auth_repository.dart';

/// Avança o relógio pouco além do debounce para disparar a busca no backend.
Duration get _debounceWait =>
    MapSearchViewModel.searchDebounce + const Duration(milliseconds: 50);

class _FakeSearchRepository implements PlaceSearchRepository {
  _FakeSearchRepository(this.results);

  final List<PlaceSuggestion> results;
  final queries = <String>[];

  @override
  Future<List<PlaceSuggestion>> search(String query) async {
    queries.add(query);
    return results;
  }

  @override
  void dispose() {}
}

class _FakeTrackingRepository implements TrackingRepository {
  final _controller = StreamController<List<TrackedLine>>.broadcast();

  void emit(List<TrackedLine> routes) => _controller.add(routes);

  @override
  Stream<List<TrackedLine>> get trackingRoutes => _controller.stream;

  @override
  Future<TrackedLine?> startTracking(String lineCode) async => null;

  @override
  Future<void> stopTracking(String lineCode) async {}

  @override
  void dispose() => _controller.close();
}

TrackedLine _trackedLine(String code) {
  return TrackedLine(
    line: Line(
      // O rastreamento usa o `sgLinha`; o `id` é o código interno do catálogo.
      name: 'Perdizes ↔ Terminal Lapa',
      origin: 'Perdizes',
      destination: 'Terminal Lapa',
      boardingCode: code,
    ),
    route: null,
    busPositions: const [],
  );
}

const _line = PlaceSuggestion(
  code: '875A-10',
  type: PlaceSuggestionType.line,
  title: 'Perdizes ↔ Terminal Lapa',
  subtitle: 'Perdizes → Terminal Lapa',
  latitude: -23.537,
  longitude: -46.676,
);

City _city(String slug, String name, String state) {
  return City(
    slug: slug,
    name: name,
    label: '$name - $state',
    state: state,
    country: 'BR',
    timezone: 'America/Fortaleza',
    latitude: -5.16,
    longitude: -42.79,
  );
}

Widget _appWithSearch(
  PlaceSearchRepository repository, {
  TrackingRepository? trackingRepository,
  AuthRepository? authRepository,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => context.push<PlaceSuggestion>('/search'),
              child: const Text('Abrir busca'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => MapSearchPage(
          repository: repository,
          trackingRepository: trackingRepository,
          authRepository: authRepository,
        ),
      ),
    ],
  );

  return MaterialApp.router(theme: AppTheme.light(), routerConfig: router);
}

void main() {
  group('MapSearchPage', () {
    testWidgets('mostra orientação enquanto não há consulta', (tester) async {
      await tester.pumpWidget(_appWithSearch(_FakeSearchRepository(const [])));
      await tester.tap(find.text('Abrir busca'));
      await tester.pumpAndSettle();

      expect(find.text('Encontre sua linha ou parada'), findsOneWidget);
      expect(find.text('Buscar linha ou parada'), findsOneWidget);
    });

    testWidgets('mostra a cidade selecionada no rodapé', (tester) async {
      final auth = FakeAuthRepository(
        city: _city('santa-aurora', 'Santa Aurora', 'SP'),
      );

      await tester.pumpWidget(
        _appWithSearch(_FakeSearchRepository(const []), authRepository: auth),
      );
      await tester.tap(find.text('Abrir busca'));
      await tester.pumpAndSettle();

      expect(find.text('Santa Aurora, SP'), findsOneWidget);
      expect(find.text('Encontre sua linha ou parada'), findsOneWidget);
    });

    testWidgets('mantém a cidade no rodapé quando há resultados', (
      tester,
    ) async {
      final auth = FakeAuthRepository(
        city: _city('santa-aurora', 'Santa Aurora', 'SP'),
      );

      await tester.pumpWidget(
        _appWithSearch(
          _FakeSearchRepository(const [_line]),
          authRepository: auth,
        ),
      );
      await tester.tap(find.text('Abrir busca'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '875');
      await tester.pump(_debounceWait);
      await tester.pumpAndSettle();

      expect(find.text('875A-10'), findsOneWidget);
      expect(find.text('Santa Aurora, SP'), findsOneWidget);
    });

    testWidgets('atualiza o rodapé ao trocar de cidade', (tester) async {
      final auth = FakeAuthRepository(
        city: _city('santa-aurora', 'Santa Aurora', 'SP'),
      );

      await tester.pumpWidget(
        _appWithSearch(_FakeSearchRepository(const []), authRepository: auth),
      );
      await tester.tap(find.text('Abrir busca'));
      await tester.pumpAndSettle();

      expect(find.text('Santa Aurora, SP'), findsOneWidget);

      await auth.selectCity(_city('teresina', 'Teresina', 'PI'));
      await tester.pumpAndSettle();

      expect(find.text('Santa Aurora, SP'), findsNothing);
      expect(find.text('Teresina, PI'), findsOneWidget);
    });

    testWidgets('busca e devolve a sugestão escolhida', (tester) async {
      PlaceSuggestion? selected;
      final repository = _FakeSearchRepository(const [_line]);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    selected = await context.push<PlaceSuggestion>('/search');
                  },
                  child: const Text('Abrir busca'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => MapSearchPage(repository: repository),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );

      await tester.tap(find.text('Abrir busca'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '875');
      await tester.pump(_debounceWait);
      await tester.pumpAndSettle();

      expect(repository.queries, ['875']);
      expect(find.text('875A-10'), findsOneWidget);
      expect(find.text('Perdizes ↔ Terminal Lapa'), findsOneWidget);

      await tester.tap(find.text('875A-10'));
      await tester.pumpAndSettle();

      expect(selected?.code, _line.code);
      expect(find.text('Abrir busca'), findsOneWidget);
    });

    testWidgets('marca a linha já rastreada como acompanhando no mapa', (
      tester,
    ) async {
      final trackingRepository = _FakeTrackingRepository();
      addTearDown(trackingRepository.dispose);

      await tester.pumpWidget(
        _appWithSearch(
          _FakeSearchRepository(const [_line]),
          trackingRepository: trackingRepository,
        ),
      );
      await tester.tap(find.text('Abrir busca'));
      await tester.pumpAndSettle();

      trackingRepository.emit([_trackedLine(_line.code)]);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '875');
      await tester.pump(_debounceWait);
      await tester.pumpAndSettle();

      expect(find.text('Acompanhando no mapa'), findsOneWidget);
    });

    testWidgets('reabre com a busca e os resultados anteriores', (
      tester,
    ) async {
      PlaceSuggestion? selected;
      final repository = _FakeSearchRepository(const [_line]);
      final cache = MapSearchCache();
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    selected = await context.push<PlaceSuggestion>('/search');
                  },
                  child: const Text('Abrir busca'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => MapSearchPage(
              viewModel: MapSearchViewModel(repository, cache: cache),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );

      await tester.tap(find.text('Abrir busca'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '875');
      await tester.pump(_debounceWait);
      await tester.pumpAndSettle();

      expect(repository.queries, ['875']);
      expect(find.text('875A-10'), findsOneWidget);

      await tester.tap(find.text('875A-10'));
      await tester.pumpAndSettle();

      expect(selected?.code, _line.code);
      expect(repository.queries, ['875']);

      await tester.tap(find.text('Abrir busca'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, '875');
      expect(find.text('875A-10'), findsOneWidget);
      expect(repository.queries, ['875']);
    });

    testWidgets('estado vazio oferece editar a busca', (tester) async {
      await tester.pumpWidget(_appWithSearch(_FakeSearchRepository(const [])));
      await tester.tap(find.text('Abrir busca'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Aeroporto');
      await tester.pump(_debounceWait);
      await tester.pumpAndSettle();

      expect(find.text('Não encontramos\n“Aeroporto”'), findsOneWidget);
      expect(find.text('Editar busca'), findsOneWidget);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.ensureVisible(find.text('Editar busca'));
      await tester.tap(find.text('Editar busca'));
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode?.hasFocus, isTrue);
    });
  });
}
