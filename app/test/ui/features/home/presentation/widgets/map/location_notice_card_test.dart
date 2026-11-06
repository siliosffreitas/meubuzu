import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/domain/models/user_coordinates.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_location_state.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/widgets/location_notice_card.dart';

const _readyPosition = UserCoordinates(latitude: -5.0629, longitude: -42.7932);

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

LocationNoticeCard _card(
  MapLocationState state, {
  VoidCallback? onOpenLocationSettings,
  VoidCallback? onRequestPermission,
  VoidCallback? onOpenAppSettings,
  VoidCallback? onRetry,
}) {
  return LocationNoticeCard(
    state: state,
    onOpenLocationSettings: onOpenLocationSettings ?? () {},
    onRequestPermission: onRequestPermission ?? () {},
    onOpenAppSettings: onOpenAppSettings ?? () {},
    onRetry: onRetry ?? () {},
  );
}

void main() {
  group('LocationNoticeCard', () {
    testWidgets('sem GPS mostra erro e não oferece ação', (tester) async {
      await tester.pumpWidget(_wrap(_card(const MapLocationNoGpsHardware())));

      expect(find.text('GPS indisponível'), findsOneWidget);
      expect(find.textContaining('não possui GPS'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('GPS desligado oferece abrir as configurações', (tester) async {
      var opened = false;
      await tester.pumpWidget(
        _wrap(
          _card(
            const MapLocationServiceDisabled(),
            onOpenLocationSettings: () => opened = true,
          ),
        ),
      );

      expect(find.text('Ligue o GPS'), findsOneWidget);

      await tester.tap(find.text('Abrir configurações'));
      expect(opened, isTrue);
    });

    testWidgets('permissão negada oferece pedir novamente', (tester) async {
      var requested = false;
      await tester.pumpWidget(
        _wrap(
          _card(
            const MapLocationPermissionDenied(),
            onRequestPermission: () => requested = true,
          ),
        ),
      );

      expect(
        find.textContaining('O app funciona melhor com a sua localização'),
        findsOneWidget,
      );

      await tester.tap(find.text('Permitir localização'));
      expect(requested, isTrue);
    });

    testWidgets('permissão negada permanentemente abre o app', (tester) async {
      var opened = false;
      await tester.pumpWidget(
        _wrap(
          _card(
            const MapLocationPermissionDeniedForever(),
            onOpenAppSettings: () => opened = true,
          ),
        ),
      );

      await tester.tap(find.text('Abrir configurações'));
      expect(opened, isTrue);
    });

    testWidgets('posição pronta não exibe aviso', (tester) async {
      await tester.pumpWidget(
        _wrap(_card(const MapLocationReady(_readyPosition))),
      );

      expect(find.byType(FilledButton), findsNothing);
      expect(find.textContaining('GPS'), findsNothing);
      expect(find.textContaining('localização'), findsNothing);
    });
  });
}
