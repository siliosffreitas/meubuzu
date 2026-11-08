import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meubuzu/data/models/place_suggestion.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/domain/models/tracked_line.dart';
import 'package:meubuzu/domain/repositories/place_search_repository.dart';
import 'package:meubuzu/domain/repositories/tracking_repository.dart';
import 'package:meubuzu/ui/core/theme/app_theme.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_search_page.dart';

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
      id: code,
      name: 'Perdizes ↔ Terminal Lapa',
      origin: 'Perdizes',
      destination: 'Terminal Lapa', boardingCode: '0101',
    ),
    route: null,
    busPositions: const [],
  );
}

const _line = PlaceSuggestion(
  id: '875A-10',
  code: '875A-10',
  type: PlaceSuggestionType.line,
  title: 'Perdizes ↔ Terminal Lapa',
  subtitle: 'Perdizes → Terminal Lapa',
  latitude: -23.537,
  longitude: -46.676,
);

Widget _appWithSearch(
  PlaceSearchRepository repository, {
  TrackingRepository? trackingRepository,
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
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(repository.queries, ['875']);
      expect(find.text('875A-10'), findsOneWidget);
      expect(find.text('Perdizes ↔ Terminal Lapa'), findsOneWidget);

      await tester.tap(find.text('875A-10'));
      await tester.pumpAndSettle();

      expect(selected?.id, _line.id);
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
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Acompanhando no mapa'), findsOneWidget);
    });

    testWidgets('estado vazio oferece editar a busca', (tester) async {
      await tester.pumpWidget(_appWithSearch(_FakeSearchRepository(const [])));
      await tester.tap(find.text('Abrir busca'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Aeroporto');
      await tester.pump(const Duration(milliseconds: 350));
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
