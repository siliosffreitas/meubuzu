import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/data/models/line.dart';
import 'package:meubuzu/ui/core/extensions/line_map_color.dart';

Line _line({String id = '1', String? boardingCode}) {
  return Line(
    id: id,
    name: 'LINHA TESTE',
    origin: 'ORIGEM',
    destination: 'DESTINO',
    boardingCode: boardingCode,
  );
}

void main() {
  group('lineMapColor', () {
    test('é determinística para o mesmo código', () {
      expect(lineMapColor('0301'), lineMapColor('0301'));
      expect(lineMapColor(' 0301 '), lineMapColor('0301'));
    });

    test('gera cores diferentes para códigos diferentes', () {
      const codes = ['0001', '0002', '0004', '0301', '0402', '1003'];
      final colors = codes.map(lineMapColor).toSet();

      expect(colors, hasLength(codes.length));
    });

    test('mantém contraste para texto branco', () {
      const codes = ['0001', '0301', '0402', '1003', 'T832', '999999'];
      for (final code in codes) {
        expect(lineMapColor(code).computeLuminance(), lessThan(0.2));
      }
    });
  });

  group('LineMapColor', () {
    test('deriva a cor do boardingCode', () {
      final line = _line(id: '46', boardingCode: '0301');

      expect(line.mapColor, lineMapColor('0301'));
    });

    test('usa o mesmo código de embarque para linhas diferentes', () {
      final first = _line(id: '46', boardingCode: '0301');
      final second = _line(id: '999', boardingCode: '0301');

      expect(first.mapColor, second.mapColor);
    });

    test('usa o id quando não há boardingCode', () {
      final line = _line(id: '408');

      expect(line.mapColor, lineMapColor('408'));
    });

    test('usa o id quando o boardingCode está vazio', () {
      final line = _line(id: '408', boardingCode: '  ');

      expect(line.mapColor, lineMapColor('408'));
    });
  });
}
