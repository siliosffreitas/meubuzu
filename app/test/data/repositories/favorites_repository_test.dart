import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/data/repositories/favorites_repository.dart';
import 'package:meubuzu/data/services/favorites_service.dart';
import 'package:meubuzu/domain/models/city.dart';
import 'package:meubuzu/domain/models/favorite.dart';

import '../../helpers/fake_auth_repository.dart';

Favorite _favorite(
  String boardingCode, {
  String citySlug = 'teresina',
  String cityName = 'Teresina',
  String cityLabel = 'Teresina - PI',
}) => Favorite.fromJson({
  'boardingCode': boardingCode,
  'line': {
    'name': 'LINHA $boardingCode',
    'origin': 'Origem',
    'destination': 'Destino',
    'boardingCode': boardingCode,
  },
  'city': {
    'slug': citySlug,
    'name': cityName,
    'label': cityLabel,
    'timezone': 'America/Fortaleza',
  },
});

class _FakeFavoritesService implements FavoritesService {
  List<Favorite> favorites = [];
  final added = <Map<String, String>>[];
  final removed = <Map<String, String>>[];
  bool shouldFail = false;
  final Map<String, Favorite> addResults = {};

  @override
  Future<List<Favorite>> fetch() async {
    if (shouldFail) {
      throw StateError('offline');
    }
    return List.unmodifiable(favorites);
  }

  @override
  Future<Favorite> add(String boardingCode, String citySlug) async {
    added.add({'boardingCode': boardingCode, 'citySlug': citySlug});
    final favorite =
        addResults[boardingCode] ??
        _favorite(boardingCode, citySlug: citySlug);
    favorites = [...favorites, favorite];
    return favorite;
  }

  @override
  Future<void> remove(String citySlug, String boardingCode) async {
    removed.add({'citySlug': citySlug, 'boardingCode': boardingCode});
    favorites =
        favorites
            .where(
              (item) =>
                  !(item.citySlug == citySlug &&
                      item.displayCode == boardingCode),
            )
            .toList();
  }
}

City get _city => City(
  slug: 'teresina',
  name: 'Teresina',
  label: 'Teresina - PI',
  state: 'PI',
  country: 'Brasil',
  timezone: 'America/Fortaleza',
  latitude: -5.1,
  longitude: -42.8,
  isActive: true,
);

void main() {
  late _FakeFavoritesService service;
  late FakeAuthRepository auth;
  late FavoritesRepositoryImpl repository;

  setUp(() {
    service = _FakeFavoritesService();
    auth = FakeAuthRepository(user: null, city: _city);
    repository = FavoritesRepositoryImpl(service, auth);
  });

  tearDown(() => repository.dispose());

  test('refresh publica os favoritos recebidos do backend', () async {
    service.favorites = [_favorite('linha-1'), _favorite('linha-2')];
    final emissions = <int>[];
    final subscription = repository.favorites.listen((items) {
      emissions.add(items.length);
    });

    await repository.refresh();
    await Future<void>.delayed(Duration.zero);

    expect(emissions, [0, 2]);
    expect(repository.snapshot.map((item) => item.displayCode), [
      'linha-1',
      'linha-2',
    ]);
    expect(repository.isFavorite('linha-1'), isTrue);
    expect(repository.isFavorite('linha-3'), isFalse);
    await subscription.cancel();
  });

  test('add usa a cidade selecionada e toggle remove o favorito', () async {
    await repository.add('linha-1');

    expect(service.added, [
      {'boardingCode': 'linha-1', 'citySlug': 'teresina'},
    ]);
    expect(repository.isFavorite('linha-1'), isTrue);

    await repository.toggle('linha-1');

    expect(service.removed, [
      {'citySlug': 'teresina', 'boardingCode': 'linha-1'},
    ]);
    expect(repository.isFavorite('linha-1'), isFalse);
  });

  test('remove usa a cidade do favorito, mesmo sem cidade selecionada', () async {
    service.favorites = [
      _favorite('1', citySlug: 'outra', cityName: 'Outra'),
    ];
    await repository.refresh();

    await repository.remove('1');

    expect(service.removed, [
      {'citySlug': 'outra', 'boardingCode': '1'},
    ]);
  });

  test('add não duplica e exige cidade selecionada', () async {
    await repository.add('linha-1');
    await repository.add('linha-1');
    expect(service.added, hasLength(1));

    final withoutCity = FavoritesRepositoryImpl(service, FakeAuthRepository());
    addTearDown(withoutCity.dispose);
    expect(() => withoutCity.add('linha-2'), throwsA(isA<StateError>()));
  });

  test('refresh propaga falha do backend', () async {
    service.shouldFail = true;
    expect(repository.refresh(), throwsA(isA<StateError>()));
  });

  test('refresh ordena favoritos por cidade e sgLinha', () async {
    service.favorites = [
      _favorite('10'),
      _favorite('2'),
      _favorite('0301'),
    ];

    await repository.refresh();

    expect(repository.snapshot.map((item) => item.displayCode), [
      '2',
      '10',
      '0301',
    ]);
  });

  test('add insere favorito na posição correta por sgLinha', () async {
    service.favorites = [_favorite('10'), _favorite('2')];
    await repository.refresh();
    service.addResults['5'] = _favorite('5');

    await repository.add('5');

    expect(repository.snapshot.map((item) => item.displayCode), [
      '2',
      '5',
      '10',
    ]);
  });
}
