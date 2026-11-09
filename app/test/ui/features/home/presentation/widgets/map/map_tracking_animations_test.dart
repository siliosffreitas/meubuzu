import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:meubuzu/ui/features/home/presentation/widgets/map/map_tracking_animations.dart';

const _oldPosition = LatLng(-5.10, -42.80);
const _newPosition = LatLng(-5.09, -42.80);

void main() {
  group('TrackingBusAnimator', () {
    testWidgets('anima da posição antiga até a nova em 300 ms', (tester) async {
      final animator = TrackingBusAnimator(vsync: const TestVSync());
      addTearDown(animator.dispose);

      animator.jumpTo({'bus': _oldPosition});
      expect(animator.positions['bus'], _oldPosition);

      animator.animateTo({'bus': _newPosition});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      final middle = animator.positions['bus']!;
      expect(middle.latitude, closeTo(-5.095, 0.0005));
      expect(animator.isAnimating, isTrue);

      // O controlador encerra no quadro seguinte ao fim dos 300 ms.
      await tester.pump(const Duration(milliseconds: 151));

      expect(animator.positions['bus'], _newPosition);
      expect(animator.isAnimating, isFalse);
    });

    testWidgets('primeira posição aparece direto no destino', (tester) async {
      final animator = TrackingBusAnimator(vsync: const TestVSync());
      addTearDown(animator.dispose);

      animator.animateTo({'bus': _oldPosition});

      expect(animator.positions['bus'], _oldPosition);
      expect(animator.isAnimating, isFalse);
    });

    testWidgets('ônibus novo aparece no destino enquanto outro anima', (
      tester,
    ) async {
      final animator = TrackingBusAnimator(vsync: const TestVSync());
      addTearDown(animator.dispose);

      animator.jumpTo({'antigo': _oldPosition});
      animator.animateTo({
        'antigo': _newPosition,
        'novo': const LatLng(-5.20, -42.90),
      });

      expect(animator.positions['novo'], const LatLng(-5.20, -42.90));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(animator.positions['antigo']!.latitude, closeTo(-5.095, 0.0005));
      expect(animator.positions['novo'], const LatLng(-5.20, -42.90));

      // Encerra a animação pendente antes do fim do teste.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('remove o ônibus que deixou de ser acompanhado', (
      tester,
    ) async {
      final animator = TrackingBusAnimator(vsync: const TestVSync());
      addTearDown(animator.dispose);

      animator.jumpTo({
        'mantido': _oldPosition,
        'removido': const LatLng(-5.20, -42.90),
      });
      animator.animateTo({'mantido': _newPosition});

      expect(animator.positions.keys, ['mantido']);

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('reinicia a partir da posição interpolada', (tester) async {
      final animator = TrackingBusAnimator(vsync: const TestVSync());
      addTearDown(animator.dispose);

      animator.jumpTo({'bus': _oldPosition});
      animator.animateTo({'bus': _newPosition});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final middle = animator.positions['bus']!;

      animator.animateTo({'bus': const LatLng(-5.08, -42.80)});

      expect(animator.positions['bus'], middle);
      expect(animator.isAnimating, isTrue);

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('não anima quando as posições não mudam', (tester) async {
      final animator = TrackingBusAnimator(vsync: const TestVSync());
      addTearDown(animator.dispose);

      animator.jumpTo({'bus': _oldPosition});
      animator.animateTo({'bus': _oldPosition});

      expect(animator.isAnimating, isFalse);
      expect(animator.positions['bus'], _oldPosition);
    });

    testWidgets('a transição dura 300 milissegundos por padrão', (
      tester,
    ) async {
      final animator = TrackingBusAnimator(vsync: const TestVSync());
      addTearDown(animator.dispose);

      expect(animator.duration, const Duration(milliseconds: 300));
    });
  });
}
