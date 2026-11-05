# Arquitetura do aplicativo MeuBuzu

Este documento detalha como o app Flutter em `app/` está organizado. Ele segue a
[arquitetura recomendada pela equipe do Flutter](https://docs.flutter.dev/app-architecture)
e complementa o resumo em [`README.md`](./README.md).

## Visão geral

O app é dividido em três camadas: **UI**, **DOMAIN** (opcional) e **DATA**.

```text
┌──────────────────────────────────────────────┐
│ UI                                           │
│  pages/views  ──►  view models               │
└──────────────────┬───────────────────────────┘
                   │
┌──────────────────▼───────────────────────────┐
│ DOMAIN (opcional)                            │
│  use cases                                   │
└──────────────────┬───────────────────────────┘
                   │
┌──────────────────▼───────────────────────────┐
│ DATA                                         │
│  repositories  ──►  services                 │
└──────────────────────────────────────────────┘
```

As dependências apontam sempre para baixo: a UI conhece o domínio e os dados, o
domínio conhece os dados, mas os dados não conhecem a UI nem o domínio. Um
service nunca conhece um repository.

O app usa **MVVM** na camada de UI e injeção de dependência por construtor. As
camadas que não pertencem a uma única funcionalidade ficam no topo de `lib/`:
os dados em `lib/data/` e, quando existir, o domínio em `lib/domain/`. A UI
continua organizada por funcionalidade em `lib/features/<feature>/presentation/`.

## Camada de UI

Local: `lib/features/<feature>/presentation/`.

- **Views, pages e tabs** (`*_page.dart`, `*_tab.dart`) exibem o estado e
  encaminham as ações do usuário. Não concentram regra de negócio.
- **Widgets** (`presentation/widgets/`) são pedaços reutilizáveis da tela.
  Devem ser simples e receber dados/ações por parâmetro.
- **View models** (`*_view_model.dart`) estendem `ChangeNotifier`, mantêm
  estado privado, expõem getters e métodos de ação e chamam `notifyListeners()`
  quando o estado muda.

Regras da camada:

- A view observa o view model com `AnimatedBuilder` ou `ListenableBuilder`.
  `setState` é usado apenas para estado local de UI (aba selecionada, marcadores
  do mapa, foco de campo).
- O view model não importa arquivos `*_service.dart`. Ele conversa com a camada
  de dados pelos contratos de repository.
- O view model recebe suas dependências pelo construtor, com valor padrão
  quando fizer sentido, para permitir fakes nos testes.
- Textos de interface são em português; nomes de classes, variáveis e arquivos
  seguem o inglês já usado no projeto.

## Camada de domínio (opcional)

Local: `lib/domain/` para use cases compartilhados. Um use case que só atende
uma funcionalidade pode ficar em `lib/features/<feature>/domain/`.

- **Use cases** encapsulam uma regra de negócio ou um fluxo que não pertence à
  apresentação. Cada use case tem uma responsabilidade e recebe repositories
  pelo construtor.
- A camada não existe por padrão. Ela só é criada quando há regra reutilizada
  por mais de um view model, lógica de negócio que precisa ser testada
  isoladamente, combinação de repositories ou regras do produto (por exemplo,
  as cotas do teste gratuito de 7 dias).

Evite criar pastas `domain/` vazias ou use cases que apenas repassam a chamada
para um repository.

## Camada de dados

Local: `lib/data/`, fora de `features/`, porque repositórios e services não
pertencem a uma única funcionalidade.

```text
lib/data/
  models/         # modelos imutáveis compartilhados
  repositories/   # contratos + implementações
  services/       # integrações externas
```

- **Repositories** são a fonte única de verdade dos dados usados pela
  apresentação. Isolam a UI e as regras da aplicação dos detalhes de acesso.
  - O contrato é declarado como `abstract interface class <Feature>Repository`.
  - A implementação fica no mesmo arquivo ou em um arquivo próprio, com prefixo
    que indica a origem: `Device...`, `Api...`, `Local...` ou `Fake...`.
  - Podem expor `Future` (operações pontuais) ou `Stream` (dados que mudam),
    guardar o último valor conhecido e traduzir erros das fontes externas para
    erros da aplicação.
- **Services** encapsulam integrações com fontes externas: API do backend,
  armazenamento local, plugins e recursos de plataforma. Não contêm regra de
  negócio nem conhecem a UI.
- **Modelos** (`UserCoordinates`, `PlaceSuggestion`, `InvalidCodeException`)
  são imutáveis (`const`/`final`) e ficam em `models/` quando compartilhados
  por mais de uma funcionalidade; caso contrário, podem ficar junto do
  repository que os expõe.

Exemplo atual:

```text
data/
  models/
    user_coordinates.dart            # modelo imutável
  repositories/
    auth_repository.dart             # AuthRepository + FakeAuthRepository
    place_search_repository.dart     # PlaceSearchRepository + FakePlaceSearchRepository
    user_location_repository.dart    # UserLocationRepository + DeviceUserLocationRepository
  services/
    location_service.dart            # LocationService + DeviceLocationService
```

## Regras de dependência

| Camada        | Pode importar                          | Não deve importar                          |
| ------------- | -------------------------------------- | ------------------------------------------ |
| UI            | domínio, contratos de repository, core | implementações de service                  |
| Domínio       | contratos de repository                | UI, services, plugins                      |
| Dados         | services, modelos, core                | UI, view models, domínio                   |

A única exceção fica na **raiz de composição** da funcionalidade: o widget que
cria o view model também instancia o repository e, para isso, a implementação
concreta do service. Nenhum outro widget nem view model importa services.
Exemplo em `map_tab.dart`:

```dart
_locationRepository =
    widget.locationRepository ??
    DeviceUserLocationRepository(const DeviceLocationService());
_locationViewModel = MapLocationViewModel(_locationRepository);
```

O `MapLocationViewModel` conhece apenas `UserLocationRepository`; quem instancia
o `DeviceLocationService` é o `DeviceUserLocationRepository`. Isso mantém o view
model testável com um fake de repositório, sem plugins reais.

## Fluxo unidirecional

O fluxo é sempre: **view → view model → repository → service → estado → view**.

Exemplo real, a localização do usuário:

```text
MapTab (view)
  └─► MapLocationViewModel.initialize()
        └─► UserLocationRepository.refresh()
              └─► DeviceUserLocationRepository
                    └─► LocationService (GPS, serviço, permissão, posição)
              ◄── Stream<UserCoordinates> ou UserLocationException
        ◄── status atualizado + notifyListeners()
  ◄── view reage e move a câmera do mapa
```

O mesmo vale para a busca do mapa: `MapTab` → `MapSearchViewModel` →
`PlaceSearchRepository` (`FakePlaceSearchRepository` enquanto o backend não
existe).

## Estrutura de pastas

```text
app/lib/
  main.dart
  app.dart                      # MaterialApp e rota inicial
  core/
    theme/                      # AppColors, AppTheme
    widgets/                    # widgets compartilhados
  data/                         # camada de dados compartilhada
    models/                     # modelos imutáveis compartilhados
    repositories/               # contratos + implementações
    services/                   # integrações externas
  domain/                       # opcional; use cases compartilhados
  features/
    <feature>/
      presentation/
        <feature>_page.dart
        <feature>_tab.dart
        <feature>_view_model.dart
        widgets/
```

Os testes em `app/test/` espelham essa estrutura:

```text
app/test/
  data/repositories/            # testes de repositório
  features/<feature>/presentation/
  helpers/
```

## Convenções

- Arquivos em `snake_case`; classes em `UpperCamelCase`; membros em
  `camelCase`.
- Sufixos por papel: `*_page.dart`, `*_tab.dart`, `*_view_model.dart`,
  `*_repository.dart`, `*_service.dart`.
- Contratos sem prefixo (`AuthRepository`, `LocationService`); implementações
  com prefixo de origem (`FakeAuthRepository`, `DeviceLocationService`).
- Prefira construtores `const` e modelos imutáveis.
- Nunca versione segredos nem registre códigos temporários de autenticação.

## Erros e estados

- A camada de dados traduz exceções de plugins/HTTP para erros da aplicação
  (`UserLocationException` com `UserLocationFailure`, `InvalidCodeException`).
- O view model converte esses erros em estados de UI (`MapLocationStatus`,
  mensagens de erro) e nunca expõe a exceção crua para a view.
- Cada fluxo deve ter estados explícitos de carregamento, sucesso, vazio e erro.

## Injeção de dependência

- Sempre por construtor: `MapSearchViewModel(repository)`,
  `MapLocationViewModel(repository)`, `AuthEmailViewModel(repository)`.
- Nos widgets, a dependência é um parâmetro opcional (com valor padrão `const`
  quando possível), para permitir fakes. Exemplos: `MapTab(searchRepository:)` e
  `MapTab(locationRepository:)`.
- Não use localizadores globais (service locator) nem singletons escondidos.
- O widget que cria uma dependência com recursos (streams, controllers) também
  é responsável por liberá-la em `dispose()`.

## Testes

- Testes unitários de view model com fakes de repository, registrando chamadas
  para verificar a ordem do fluxo.
- Testes de repository com fakes de service (`DeviceUserLocationRepository` com
  um `LocationService` fake, por exemplo).
- Testes de widget para estados da tela e do card de aviso.
- Nunca chame plugins reais (`geolocator`, Google Maps) em teste.
- Comandos:

  ```sh
  cd app
  flutter analyze
  flutter test
  ```

## Quando criar cada componente

| Componente  | Crie quando                                                        | Onde fica                          |
| ----------- | ------------------------------------------------------------------ | ---------------------------------- |
| Service     | houver integração com API, banco, plugin ou plataforma             | `lib/data/services/`               |
| Repository  | houver dados a expor para a UI (mesmo que venham de um service)    | `lib/data/repositories/`           |
| Use case    | a regra for reutilizada por 2+ view models ou combinar repositories | `lib/domain/` (opcional)           |
| View model  | a tela tiver estado que muda e ações a coordenar                   | `features/<feature>/presentation/` |
| Widget      | o trecho de UI se repetir ou a página ficar grande demais          | `features/<feature>/presentation/` |

## Estado atual das features

Os dados compartilhados ficam em `lib/data/`; a tabela abaixo mostra quais
deles cada funcionalidade usa. Nenhuma feature tem camada de domínio por
enquanto.

| Feature   | Presentation                                                   | Dados usados                                                                                | Domain |
| --------- | -------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | ------ |
| auth      | e-mail e código, com view models                               | `AuthRepository` + `FakeAuthRepository`                                                     | —      |
| home      | `HomePage` e navegação por abas                                | —                                                                                           | —      |
| map       | `MapTab`, `MapLocationViewModel`, `MapSearchViewModel`, widgets | `UserLocationRepository`, `PlaceSearchRepository`, `LocationService`, `UserCoordinates`      | —      |
| favorites | `FavoritesTab`                                                 | —                                                                                           | —      |
| account   | `AccountTab`                                                   | —                                                                                           | —      |
| core      | `AppColors`, `AppTheme`, `EmptyState`, `TabHeader`             | —                                                                                           | —      |

## Referências

- [Flutter — Arquitetura de aplicações](https://docs.flutter.dev/app-architecture)
- [Flutter — Guia de arquitetura](https://docs.flutter.dev/app-architecture/guide)
- [Flutter — Casos de uso (camada de domínio)](https://docs.flutter.dev/app-architecture/case-study)
