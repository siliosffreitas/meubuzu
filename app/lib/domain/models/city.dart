/// Cidade atendida pelo MeuBuzu.
///
/// O [slug] é o identificador usado nas rotas `/v1/cities/{citySlug}/...` e o
/// [timezone] define o dia da cota de rastreamento.
class City {
  const City({
    required this.slug,
    required this.name,
    required this.label,
    required this.state,
    required this.country,
    required this.timezone,
    required this.latitude,
    required this.longitude,
    this.isActive = true,
    this.coverageNote,
  });

  final String slug;
  final String name;
  final String label;
  final String state;
  final String country;
  final String timezone;
  final double latitude;
  final double longitude;
  final bool isActive;
  final String? coverageNote;

  /// Rótulo curto para cabeçalhos: `"Nome, UF"` quando há UF, senão `"Nome"`.
  ///
  /// Diferente de [label] (que vem da API no formato `"Nome - UF"`), este
  /// getter é usado nos indicadores de cidade do mapa e da busca.
  String get displayLabel {
    final uf = state.trim();
    return uf.isEmpty ? name : '$name, $uf';
  }

  /// Lê uma cidade de um JSON, devolvendo `null` quando o valor não é um mapa.
  static City? fromJsonOrNull(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    return City.fromJson(json);
  }

  factory City.fromJson(Map<String, dynamic> json) {
    final center = json['center'];
    final centerMap = center is Map<String, dynamic>
        ? center
        : const <String, dynamic>{};
    final name = json['name'] as String? ?? '';

    return City(
      slug: json['slug'] as String? ?? '',
      name: name,
      label: json['label'] as String? ?? name,
      state: json['state'] as String? ?? '',
      country: json['country'] as String? ?? 'BR',
      timezone: json['timezone'] as String? ?? '',
      latitude: _toDouble(centerMap['latitude']),
      longitude: _toDouble(centerMap['longitude']),
      isActive: json['isActive'] as bool? ?? true,
      coverageNote: json['coverageNote'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'name': name,
      'label': label,
      'state': state,
      'country': country,
      'timezone': timezone,
      'center': {'latitude': latitude, 'longitude': longitude},
      'isActive': isActive,
      'coverageNote': coverageNote,
    };
  }

  static double _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  @override
  bool operator ==(Object other) {
    return other is City && other.slug == slug;
  }

  @override
  int get hashCode => slug.hashCode;
}
