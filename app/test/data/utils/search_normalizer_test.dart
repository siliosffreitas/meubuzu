import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/data/utils/search_normalizer.dart';

void main() {
  group('normalizeSearchText', () {
    test('remove acentuação e normaliza a caixa', () {
      expect(
        normalizeSearchText('POTY VELHO B. ESPERANCA'),
        'poty velho b. esperanca',
      );
      expect(
        normalizeSearchText('PERDIZES ↔ TERMINAL LAPA'),
        'perdizes ↔ terminal lapa',
      );
    });

    test('remove espaços das extremidades', () {
      expect(normalizeSearchText('  875A-10  '), '875a-10');
    });
  });
}
