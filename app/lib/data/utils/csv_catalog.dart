/// Utilitários de leitura de catálogos CSV locais.
library;

/// Divide o conteúdo CSV em linhas e colunas, respeitando campos entre aspas.
List<List<String>> parseCsvRows(String content) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;

  for (var index = 0; index < content.length; index++) {
    final character = content[index];

    if (inQuotes) {
      if (character == '"') {
        if (index + 1 < content.length && content[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(character);
      }
      continue;
    }

    switch (character) {
      case '"':
        inQuotes = true;
      case ',':
        row.add(field.toString());
        field.clear();
      case '\n':
        row.add(field.toString());
        field.clear();
        rows.add(row);
        row = <String>[];
      case '\r':
        break;
      default:
        field.write(character);
    }
  }

  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }

  return rows;
}

/// Retorna o índice de uma coluna no cabeçalho normalizado.
///
/// Lança um [FormatException] quando a coluna não existe no catálogo.
int columnIndex(List<String> header, String column, String assetPath) {
  final index = header.indexOf(column);
  if (index < 0) {
    throw FormatException('Coluna "$column" ausente em $assetPath');
  }
  return index;
}
