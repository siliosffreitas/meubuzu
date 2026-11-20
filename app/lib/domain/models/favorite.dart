import 'line.dart';

/// Cidade de uma linha favorita, devolvida pelo endpoint de favoritos.
class FavoriteCity {
  const FavoriteCity({
    required this.slug,
    required this.name,
    required this.label,
    required this.timezone,
  });

  final String slug;
  final String name;
  final String label;
  final String timezone;

  factory FavoriteCity.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? '';
    return FavoriteCity(
      slug: json['slug']?.toString() ?? '',
      name: name,
      label: json['label']?.toString() ?? name,
      timezone: json['timezone']?.toString() ?? '',
    );
  }

  /// Texto usado no cabeçalho do grupo na aba Favoritos.
  String get displayLabel => label.trim().isEmpty ? name : label;
}

/// Linha favorita vinculada à conta do usuário.
///
/// Um favorito é identificado por `citySlug` + `boardingCode`; IDs internos
/// não fazem parte do contrato público.
class Favorite {
  const Favorite({
    required this.boardingCode,
    required this.line,
    required this.city,
    required this.createdAt,
  });

  final String boardingCode;
  final Line line;
  final FavoriteCity city;
  final DateTime? createdAt;

  factory Favorite.fromJson(Map<String, dynamic> json) {
    final lineJson = json['line'];
    final cityJson = json['city'];
    final line = lineJson is Map<String, dynamic>
        ? Line.fromJson(lineJson)
        : Line.fromJson(const {});

    return Favorite(
      boardingCode:
          _text(json['boardingCode']) ?? line.publicCode,
      line: line,
      city: cityJson is Map<String, dynamic>
          ? FavoriteCity.fromJson(cityJson)
          : FavoriteCity.fromJson(const {}),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }

  static String? _text(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  /// Slug da cidade do favorito, usado na remoção.
  String get citySlug => city.slug.trim();

  /// Código exibido e usado na navegação para detalhes da linha.
  String get displayCode {
    final code = boardingCode.trim();
    return code.isEmpty ? line.publicCode : code;
  }

  /// Trajeto curto exibido abaixo do nome da linha.
  String get routeDescription {
    final origin = line.origin.trim();
    final destination = line.destination.trim();
    if (origin.isEmpty) {
      return destination;
    }
    if (destination.isEmpty || origin == destination) {
      return origin == destination ? 'Circular • $origin' : origin;
    }
    return '$origin → $destination';
  }
}
