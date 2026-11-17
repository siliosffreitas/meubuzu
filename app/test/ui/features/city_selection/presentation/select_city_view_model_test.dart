import 'package:flutter_test/flutter_test.dart';
import 'package:meubuzu/domain/models/auth_user.dart';
import 'package:meubuzu/domain/models/city.dart';
import 'package:meubuzu/domain/repositories/auth_repository.dart';
import 'package:meubuzu/ui/features/city_selection/presentation/select_city_view_model.dart';

import '../../../../helpers/auth_test_helpers.dart';
import '../../../../helpers/fake_auth_repository.dart';
import '../../../../helpers/fake_city_repository.dart';

const _outraCidade = City(
  slug: 'outra',
  name: 'Outra',
  label: 'Outra - PI',
  state: 'PI',
  country: 'BR',
  timezone: 'America/Fortaleza',
  latitude: -5.0,
  longitude: -42.0,
);

void main() {
  group('SelectCityViewModel', () {
    FakeAuthRepository authenticated({City? city}) {
      return FakeAuthRepository(
        user: const AuthUser(id: 'user-1', email: 'ana@exemplo.com'),
        city: city,
      );
    }

    test('carrega as cidades e pré-seleciona a única disponível', () async {
      final viewModel = SelectCityViewModel(
        FakeCityRepository(cities: const [testCity]),
        authenticated(),
      );

      await viewModel.load();

      expect(viewModel.cities, hasLength(1));
      expect(viewModel.selectedCity?.slug, 'teresina');
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.canSubmit, isTrue);

      viewModel.dispose();
    });

    test('pré-seleciona a cidade atual quando ela está na lista', () async {
      final viewModel = SelectCityViewModel(
        FakeCityRepository(cities: const [_outraCidade, testCity]),
        authenticated(city: testCity),
      );

      await viewModel.load();

      expect(viewModel.selectedCity?.slug, 'teresina');

      viewModel.dispose();
    });

    test('sem cidade atual e com várias opções não seleciona nada', () async {
      final viewModel = SelectCityViewModel(
        FakeCityRepository(cities: const [_outraCidade, testCity]),
        authenticated(),
      );

      await viewModel.load();

      expect(viewModel.selectedCity, isNull);
      expect(viewModel.canSubmit, isFalse);

      viewModel.dispose();
    });

    test('notifica durante o carregamento', () async {
      final viewModel = SelectCityViewModel(
        FakeCityRepository(
          cities: const [testCity],
          latency: const Duration(milliseconds: 20),
        ),
        authenticated(),
      );
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      final future = viewModel.load();
      expect(viewModel.isLoading, isTrue);
      await future;

      expect(viewModel.isLoading, isFalse);
      expect(notifications, greaterThanOrEqualTo(2));

      viewModel.dispose();
    });

    test('mostra mensagem quando a lista vem vazia', () async {
      final viewModel = SelectCityViewModel(
        FakeCityRepository(cities: const []),
        authenticated(),
      );

      await viewModel.load();

      expect(viewModel.cities, isEmpty);
      expect(viewModel.errorMessage, 'Nenhuma cidade disponível no momento.');

      viewModel.dispose();
    });

    test('mostra mensagem quando o carregamento falha', () async {
      final viewModel = SelectCityViewModel(
        FakeCityRepository(error: Exception('sem rede')),
        authenticated(),
      );

      await viewModel.load();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, contains('Não foi possível carregar'));

      viewModel.dispose();
    });

    test('confirmar salva a cidade escolhida', () async {
      final auth = authenticated();
      final viewModel = SelectCityViewModel(
        FakeCityRepository(cities: const [testCity]),
        auth,
      );
      await viewModel.load();

      final confirmed = await viewModel.confirm();

      expect(confirmed, isTrue);
      expect(auth.selectedCities, ['teresina']);
      expect(auth.selectedCity?.slug, 'teresina');
      expect(viewModel.isSubmitting, isFalse);

      viewModel.dispose();
    });

    test('confirmar sem cidade escolhida pede uma seleção', () async {
      final viewModel = SelectCityViewModel(
        FakeCityRepository(cities: const [_outraCidade, testCity]),
        authenticated(),
      );
      await viewModel.load();

      final confirmed = await viewModel.confirm();

      expect(confirmed, isFalse);
      expect(viewModel.errorMessage, 'Escolha uma cidade para continuar.');

      viewModel.dispose();
    });

    test('confirmar trata cidade indisponível', () async {
      final auth = RecordingAuthRepository(
        user: const AuthUser(id: 'user-1', email: 'ana@exemplo.com'),
        city: _outraCidade,
        cityError: const CityUnavailableException('city_inactive'),
      );
      final viewModel = SelectCityViewModel(
        FakeCityRepository(cities: const [testCity]),
        auth,
      );
      await viewModel.load();

      final confirmed = await viewModel.confirm();

      expect(confirmed, isFalse);
      expect(
        viewModel.errorMessage,
        'Esta cidade não está disponível. Escolha outra.',
      );

      viewModel.dispose();
    });

    test('confirmar trata falha genérica ao salvar', () async {
      final viewModel = SelectCityViewModel(
        FakeCityRepository(cities: const [testCity]),
        _FailingAuthRepository(),
      );
      await viewModel.load();

      final confirmed = await viewModel.confirm();

      expect(confirmed, isFalse);
      expect(
        viewModel.errorMessage,
        'Não foi possível salvar a cidade. Tente novamente.',
      );

      viewModel.dispose();
    });

    test('no modo de troca sempre sincroniza a cidade', () async {
      final auth = authenticated(city: testCity);
      final viewModel = SelectCityViewModel(
        FakeCityRepository(cities: const [testCity]),
        auth,
        isChangeMode: true,
      );
      await viewModel.load();

      final confirmed = await viewModel.confirm();

      expect(confirmed, isTrue);
      expect(auth.selectedCities, ['teresina']);

      viewModel.dispose();
    });

    test('escolher outra cidade atualiza a seleção', () async {
      final viewModel = SelectCityViewModel(
        FakeCityRepository(cities: const [_outraCidade, testCity]),
        authenticated(city: testCity),
      );
      await viewModel.load();

      viewModel.choose(_outraCidade);

      expect(viewModel.selectedCity?.slug, 'outra');

      viewModel.dispose();
    });
  });
}

class _FailingAuthRepository extends FakeAuthRepository {
  _FailingAuthRepository()
    : super(
        user: const AuthUser(id: 'user-1', email: 'ana@exemplo.com'),
      );

  @override
  Future<void> selectCity(City city) async {
    throw Exception('falha inesperada');
  }
}
