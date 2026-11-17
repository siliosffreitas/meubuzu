import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/domain/models/city.dart';

void main() {
  group('City', () {
    const json = {
      'slug': 'teresina',
      'name': 'Teresina',
      'label': 'Teresina - PI',
      'state': 'PI',
      'country': 'BR',
      'timezone': 'America/Fortaleza',
      'center': {'latitude': -5.16, 'longitude': -42.79},
      'isActive': true,
      'coverageNote': 'Cobertura inicial.',
    };

    test('lê o formato da API', () {
      final city = City.fromJson(json);

      expect(city.slug, 'teresina');
      expect(city.name, 'Teresina');
      expect(city.label, 'Teresina - PI');
      expect(city.state, 'PI');
      expect(city.country, 'BR');
      expect(city.timezone, 'America/Fortaleza');
      expect(city.latitude, -5.16);
      expect(city.longitude, -42.79);
      expect(city.isActive, isTrue);
      expect(city.coverageNote, 'Cobertura inicial.');
    });

    test('aceita centro em texto e valores ausentes', () {
      final city = City.fromJson({
        'slug': 'teresina',
        'name': 'Teresina',
        'center': {'latitude': '-5.16', 'longitude': '-42.79'},
      });

      expect(city.latitude, -5.16);
      expect(city.longitude, -42.79);
      expect(city.label, 'Teresina');
      expect(city.country, 'BR');
      expect(city.isActive, isTrue);
    });

    test('fromJsonOrNull ignora valores que não são mapa', () {
      expect(City.fromJsonOrNull(null), isNull);
      expect(City.fromJsonOrNull('teresina'), isNull);
      expect(City.fromJsonOrNull(const <String, dynamic>{}), isNotNull);
    });

    test('serializa e relê sem perder dados', () {
      final city = City.fromJson(json);

      final restored = City.fromJson(city.toJson());

      expect(restored.slug, city.slug);
      expect(restored.label, city.label);
      expect(restored.timezone, city.timezone);
      expect(restored.latitude, city.latitude);
      expect(restored.longitude, city.longitude);
      expect(restored.coverageNote, city.coverageNote);
    });

    test('compara cidades pelo slug', () {
      final city = City.fromJson(json);

      expect(city, City.fromJson(json));
      expect(city == City.fromJson({...json, 'slug': 'outra'}), isFalse);
      expect(city.hashCode, City.fromJson(json).hashCode);
    });
  });
}
