import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/domain/models/bus_stop.dart';
import 'package:meubuzu/ui/core/theme/app_colors.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/nearby_stop_markers.dart';

void main() {
  testWidgets('debug pixels', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const name = 'T-SANTA FÉ';
    final recorder = ui.PictureRecorder();
    final icon = paintNearbyStopMarkerIcon(ui.Canvas(recorder), name);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      icon.size.width.ceil(),
      icon.size.height.ceil(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = data!.buffer.asUint8List();
    final width = icon.size.width.ceil();

    final ringTop = icon.ringCenter.dy - nearbyStopMarkerDiameter / 2;
    final ringRight = icon.ringCenter.dx + nearbyStopMarkerDiameter / 2;
    final primary = AppColors.primary.toARGB32();

    final hist = <int, int>{};
    var painted = 0;
    for (var y = 0; y < ringTop.ceil(); y++) {
      for (var x = ringRight.ceil(); x < width; x++) {
        final i = (y * width + x) * 4;
        final a = bytes[i + 3];
        if (a == 0) continue;
        painted++;
        final key = (bytes[i] << 24) | (bytes[i + 1] << 16) |
            (bytes[i + 2] << 8) | a;
        hist[key] = (hist[key] ?? 0) + 1;
      }
    }
    // ignore: avoid_print
    print('size=${icon.size} painted=$painted');
    final entries = hist.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in entries.take(12)) {
      // ignore: avoid_print
      print(
        'argb=0x${e.key.toRadixString(16).padLeft(8, '0')} count=${e.value}',
      );
    }
    // ignore: avoid_print
    print('primary=0x${primary.toRadixString(16)}');
    picture.dispose();
    image.dispose();
    expect(painted, greaterThan(0));
  });
}
