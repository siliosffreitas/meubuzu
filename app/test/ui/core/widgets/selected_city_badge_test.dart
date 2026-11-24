import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/ui/core/theme/app_colors.dart';
import 'package:meubuzu/ui/core/widgets/selected_city_badge.dart';

Widget _app(SelectedCityBadge badge) {
  return MaterialApp(
    home: Scaffold(body: Center(child: badge)),
  );
}

void main() {
  group('SelectedCityBadge', () {
    testWidgets('mostra o rótulo da cidade no mapa', (tester) async {
      await tester.pumpWidget(
        _app(const SelectedCityBadge(label: 'Santa Aurora, SP')),
      );

      final text = tester.widget<Text>(find.text('Santa Aurora, SP'));
      expect(text.style?.fontWeight, FontWeight.w700);
      expect(text.style?.color, AppColors.textPrimary);
    });

    testWidgets('mostra o rótulo da cidade no rodapé da busca', (tester) async {
      await tester.pumpWidget(
        _app(
          const SelectedCityBadge(
            label: 'Santa Aurora, SP',
            variant: SelectedCityBadgeVariant.footer,
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Santa Aurora, SP'));
      expect(text.style?.color, AppColors.textSecondary);
      expect(text.style?.fontWeight, isNot(FontWeight.w700));
    });

    testWidgets('não exibe texto quando não há cidade', (tester) async {
      await tester.pumpWidget(_app(const SelectedCityBadge(label: '   ')));

      expect(find.byType(Text), findsNothing);
    });
  });
}
