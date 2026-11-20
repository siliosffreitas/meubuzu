import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/domain/models/line.dart';
import 'package:meubuzu/ui/core/extensions/line_map_color.dart';

Line _line({
  String name = 'LINHA TESTE',
  String boardingCode = '0301',
}) {
  return Line(
    name: name,
    origin: 'ORIGEM',
    destination: 'DESTINO',
    boardingCode: boardingCode,
  );
}

void main() {
  group('lineMapColor', () {
    test('é determinística para o mesmo código e nome', () {
      expect(
        lineMapColor('0301', 'MOCAMBINHO'),
        lineMapColor('0301', 'MOCAMBINHO'),
      );
      expect(
        lineMapColor(' 0301 ', ' MOCAMBINHO '),
        lineMapColor('0301', 'MOCAMBINHO'),
      );
    });

    test('gera cores diferentes para códigos diferentes', () {
      const codes = ['0001', '0002', '0004', '0301', '0402', '1003'];
      final colors = codes.map((code) => lineMapColor(code, 'LINHA')).toSet();

      expect(colors, hasLength(codes.length));
    });

    test('gera cores diferentes para nomes diferentes no mesmo código', () {
      final first = lineMapColor('0301', 'MOCAMBINHO DUQUE DE CAXIAS');
      final second = lineMapColor('0301', 'MOCAMBINHO VIA CENTRO');

      expect(first, isNot(second));
    });

    test('ignora diferenças de caixa e espaços no nome', () {
      expect(
        lineMapColor('0301', 'Mocambinho Duque de Caxias'),
        lineMapColor('0301', 'MOCAMBINHO DUQUE DE CAXIAS'),
      );
    });

    test('mantém contraste para texto branco', () {
      const combinations = [
        ('0001', 'CENTRO'),
        ('0301', 'MOCAMBINHO DUQUE DE CAXIAS'),
        ('0402', 'VILA DO SOL'),
        ('1003', 'CIRCULAR PARQUE'),
        ('T832', 'TERMINAL CENTRAL'),
        ('999999', 'LINHA LONGA'),
      ];
      for (final (code, name) in combinations) {
        expect(lineMapColor(code, name).computeLuminance(), lessThan(0.2));
      }
    });
  });

  group('LineMapColor', () {
    test('deriva a cor do boardingCode e do nome', () {
      final line = _line(
        name: 'MOCAMBINHO DUQUE DE CAXIAS',
        boardingCode: '0301',
      );

      expect(line.mapColor, lineMapColor('0301', 'MOCAMBINHO DUQUE DE CAXIAS'));
    });

    test('diferencia linhas com o mesmo código de embarque', () {
      final first = _line(
        name: 'MOCAMBINHO DUQUE DE CAXIAS',
        boardingCode: '0301',
      );
      final second = _line(
        name: 'MOCAMBINHO VIA CENTRO',
        boardingCode: '0301',
      );

      expect(first.mapColor, isNot(second.mapColor));
    });

    test('linha sem código de embarque ainda tem cor determinística', () {
      final line = _line(
        name: 'BELAVISTA VIA S.MARIA',
        boardingCode: '  ',
      );

      expect(line.mapColor, lineMapColor('', 'BELAVISTA VIA S.MARIA'));
    });
  });
}
