import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/domain/models/bus_stop.dart';
import 'package:meubuzu/ui/core/theme/app_colors.dart';
import 'package:meubuzu/ui/core/widgets/stop_ring_icon.dart';
import 'package:meubuzu/ui/features/line_details/presentation/widgets/line_stop_timeline_tile.dart';

const _busStop = BusStop(
  id: '1',
  code: '2362',
  name: 'T-SANTA FÉ',
  address: 'Rua B, Teresina - PI',
  latitude: -5.165446,
  longitude: -42.791169,
);

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('exibe o nome e o código da parada', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const LineStopTimelineTile(
          stop: _busStop,
          isFirst: false,
          isLast: false,
        ),
      ),
    );

    expect(find.text('T-SANTA FÉ · 2362'), findsOneWidget);
  });

  testWidgets('usa o mesmo anel do marcador de parada do mapa', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const LineStopTimelineTile(
          stop: _busStop,
          isFirst: false,
          isLast: false,
        ),
      ),
    );

    final ring = tester.widget<StopRingIcon>(find.byType(StopRingIcon));

    expect(ring.size, stopRingDiameter);
    expect(ring.strokeWidth, stopRingStrokeWidth);
    expect(ring.color, AppColors.primary);
  });
}
