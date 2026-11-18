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
class Favorite {
  const Favorite({
    required this.id,
    required this.lineId,
    required this.line,
    required this.city,
    required this.createdAt,
  });

  final String id;
  final String lineId;
  final Line line;
  final FavoriteCity city;
  final DateTime? createdAt;

  factory Favorite.fromJson(Map<String, dynamic> json) {
    final lineJson = json['line'];
    final cityJson = json['city'];

    return Favorite(
      id: json['id']?.toString() ?? '',
      lineId: json['lineId']?.toString() ?? json['id']?.toString() ?? '',
      line: lineJson is Map<String, dynamic>
          ? Line.fromJson(lineJson)
          : Line.fromJson(const {}),
      city: cityJson is Map<String, dynamic>
          ? FavoriteCity.fromJson(cityJson)
          : FavoriteCity.fromJson(const {}),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }

  /// Código exibido e usado na navegação para detalhes da linha.
  String get displayCode {
    final boardingCode = line.boardingCode?.trim();
    return boardingCode != null && boardingCode.isNotEmpty
        ? boardingCode
        : line.id;
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
