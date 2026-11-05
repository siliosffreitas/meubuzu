import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/features/home/presentation/widgets/map/map_location_view_model.dart';
import 'package:meubuzu/features/home/presentation/widgets/map/widgets/location_notice_card.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

LocationNoticeCard _card(
  MapLocationStatus status, {
  VoidCallback? onOpenLocationSettings,
  VoidCallback? onRequestPermission,
  VoidCallback? onOpenAppSettings,
  VoidCallback? onRetry,
}) {
  return LocationNoticeCard(
    status: status,
    onOpenLocationSettings: onOpenLocationSettings ?? () {},
    onRequestPermission: onRequestPermission ?? () {},
    onOpenAppSettings: onOpenAppSettings ?? () {},
    onRetry: onRetry ?? () {},
  );
}

void main() {
  group('LocationNoticeCard', () {
    testWidgets('sem GPS mostra erro e não oferece ação', (tester) async {
      await tester.pumpWidget(_wrap(_card(MapLocationStatus.noGpsHardware)));

      expect(find.text('GPS indisponível'), findsOneWidget);
      expect(find.textContaining('não possui GPS'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('GPS desligado oferece abrir as configurações', (tester) async {
      var opened = false;
      await tester.pumpWidget(
        _wrap(
          _card(
            MapLocationStatus.serviceDisabled,
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
            MapLocationStatus.permissionDenied,
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
            MapLocationStatus.permissionDeniedForever,
            onOpenAppSettings: () => opened = true,
          ),
        ),
      );

      await tester.tap(find.text('Abrir configurações'));
      expect(opened, isTrue);
    });

    testWidgets('posição pronta não exibe aviso', (tester) async {
      await tester.pumpWidget(_wrap(_card(MapLocationStatus.ready)));

      expect(find.byType(FilledButton), findsNothing);
      expect(find.textContaining('GPS'), findsNothing);
      expect(find.textContaining('localização'), findsNothing);
    });
  });
}
