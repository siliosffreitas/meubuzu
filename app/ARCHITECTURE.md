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

O app usa **MVVM** na camada de UI e injeção de dependência com
[`auto_injector`](https://pub.dev/packages/auto_injector), encapsulado pelo
`CustomInjector`. As dependências compartilhadas são registradas uma única vez
em `lib/di/dependencies.dart` e resolvidas pelas páginas e widgets. As camadas
que não pertencem a uma única funcionalidade ficam no topo de `lib/`: os dados
em `lib/data/`, os contratos base em `lib/domain/contracts/` e o injetor em
`lib/di/`. A UI fica em `lib/ui/`, reunindo o `core/` visual e as `features/`
organizadas por funcionalidade.

## Camada de UI

Local: `lib/ui/`.

- **`lib/ui/core/`** contém apenas elementos visuais compartilhados: tema
  (`theme/`) e widgets reutilizáveis (`widgets/`).
- **`lib/ui/routing/`** concentra as rotas do GoRouter: `app_router.dart` cria o
  router e `app_routes.dart` define caminhos e nomes. As páginas navegam com
  `context.pushNamed`/`context.goNamed`.
- **`lib/ui/features/<feature>/presentation/`** contém as telas da
  funcionalidade.

- ViewModels usam **State Pattern**: emitem estados abstratos com classes concretas. A UI observa esses estados e reage aos eventos.
- **Views, pages e tabs** (`*_page.dart`, `*_tab.dart`) exibem o estado e
  encaminham as ações do usuário. Não concentram regra de negócio.
- **Widgets** (`presentation/widgets/`) são pedaços reutilizáveis da tela.
  Devem ser simples e receber dados/ações por parâmetro. As abas exibidas dentro
  da Home ficam em `lib/ui/features/home/presentation/widgets/<aba>/`.
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
uma funcionalidade pode ficar em `lib/ui/features/<feature>/domain/`.

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

Local: `lib/data/`, fora de `ui/features/`, porque repositórios e services não
pertencem a uma única funcionalidade.

```text
lib/data/
  models/         # modelos imutáveis compartilhados
  repositories/   # implementações dos repositórios
  services/       # integrações externas
```

- **Repositories** são a fonte única de verdade dos dados usados pela
  apresentação. Isolam a UI e as regras da aplicação dos detalhes de acesso.
  - O contrato é declarado em `lib/domain/repositories/` como
    `abstract interface class <Feature>Repository`.
  - A implementação fica em `lib/data/repositories/`, com prefixo que indica a
    origem: `Device...`, `Api...`, `Local...` ou `Fake...`.
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
  config/
    api_config.dart                  # URL do backend por plataforma/dart-define
  models/
    auth_user.dart                   # AuthUser (id, e-mail, nível de acesso)
    line.dart                       # Line (origem/destino, coordenadas opcionais)
    place_suggestion.dart            # PlaceSuggestion + PlaceSuggestionType
    stored_auth_session.dart         # StoredAuthSession (tokens + usuário)
    user_coordinates.dart            # modelo imutável
  repositories/
    asset_place_search_repository.dart  # AssetPlaceSearchRepository
    auth_repository.dart             # ApiAuthRepository
    details_line_repository.dart     # DetailsLineRepositoryImpl
    place_search_repository.dart     # PlaceSearchRepository
    tracking_repository.dart         # TrackingRepositoryImpl
    user_location_repository.dart    # DeviceUserLocationRepository
  services/
    api_client.dart                  # ApiClient + ApiException/NetworkException
    bus_stop_service.dart            # BusStopService + AssetBusStopService
    line_search_service.dart        # LineSearchService + AssetLineSearchService
    line_stops_service.dart          # LineStopsService + AssetLineStopsService
    location_service.dart            # LocationService + DeviceLocationService
    route_service.dart               # RouteService + AssetRouteService
    session_storage.dart             # SessionStorage + SecureSessionStorage

domain/
  repositories/
    auth_repository.dart             # AuthRepository + InvalidCodeException
    details_line_repository.dart     # DetailsLineRepository
    place_search_repository.dart     # PlaceSearchRepository
    tracking_repository.dart         # TrackingRepository
    user_location_repository.dart    # UserLocationRepository + erros
```

## Regras de dependência

| Camada   | Pode importar                                          | Não deve importar          |
| -------- | ------------------------------------------------------ | -------------------------- |
| UI       | domínio, contratos de repository, `di`, core           | implementações de service  |
| Domínio  | contratos de repository, modelos de dados              | UI, services, plugins      |
| Dados    | services, modelos, core, contratos de repositório      | UI, view models, use cases |
| `di/`    | dados, domínio, UI (view models)                       | — (é a raiz de composição) |

A **raiz de composição** fica em `lib/di/dependencies.dart`. É o único lugar
que instancia implementações concretas de service e repository e as registra no
`CustomInjector`. As páginas e widgets recebem as dependências pelo injetor, mas
continuam aceitando overrides opcionais no construtor para testes.

```dart
// lib/di/dependencies.dart
injector.addService<LocationService>(DeviceLocationService.new);
injector.addRepository<UserLocationRepository>(
  () => DeviceUserLocationRepository(
    injector.getService<LocationService>(),
  ),
);
injector.addViewModel<MapLocationViewModel>(
  () => MapLocationViewModel(
    injector.getRepository<UserLocationRepository>(),
  ),
);
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

O mesmo vale para a busca do mapa: o campo no `MapTab` abre a `MapSearchPage`,
que usa o `MapSearchViewModel` → `PlaceSearchRepository`
(`AssetPlaceSearchRepository` consultando os catálogos locais). Ao escolher uma
sugestão, a página retorna o item e o mapa exibe o marcador correspondente.

## Estrutura de pastas

```text
app/lib/
  main.dart
  app.dart                      # MaterialApp e rota inicial
  data/                         # camada de dados compartilhada
    models/                     # modelos imutáveis compartilhados
    repositories/               # implementações dos repositórios
    services/                   # integrações externas
  di/                           # composição e injeção de dependências
    custom_injector.dart        # wrapper do auto_injector
    dependencies.dart           # registro de services, repositórios e view models
  domain/
    contracts/                  # contratos base (Repository, Service, ViewmodelBase)
    repositories/               # contratos (classes abstratas) dos repositórios
  ui/                           # camada de UI
    core/                       # apenas elementos visuais compartilhados
      extensions/               # extensões de UI (ex.: cor das linhas)
      theme/                    # AppColors, AppTheme
      widgets/                  # widgets compartilhados
    routing/
      app_router.dart           # GoRouter e injeção do AuthRepository
      app_routes.dart           # caminhos e nomes das rotas
    features/
      auth/
        presentation/
          auth_email/
          auth_code/
      home/
        presentation/
          home_page.dart
          widgets/
            account/
              account_tab.dart
            favorites/
              favorites_tab.dart
            map/
              map_tab.dart
              map_location_view_model.dart
              map_search_page.dart
              map_search_view_model.dart
              map_style.dart
              widgets/
      line_details/
        presentation/
          details_line_page.dart
          details_line_state.dart
          details_line_view_model.dart
          widgets/
```

Os testes em `app/test/` espelham essa estrutura:

```text
app/test/
  data/repositories/            # testes de repositório
  ui/features/auth/presentation/
  ui/features/home/presentation/widgets/
  helpers/
```

## Convenções

- Arquivos em `snake_case`; classes em `UpperCamelCase`; membros em
  `camelCase`.
- Sufixos por papel: `*_page.dart`, `*_tab.dart`, `*_view_model.dart`,
  `*_repository.dart`, `*_service.dart`.
- Contratos sem prefixo (`AuthRepository`, `LocationService`); implementações
  com prefixo de origem (`ApiAuthRepository`, `DeviceLocationService`).
  Fakes de teste ficam em `test/helpers/`, não em `lib/`.
- Prefira construtores `const` e modelos imutáveis.
- Nunca versione segredos nem registre códigos temporários de autenticação.

## Erros e estados

- A camada de dados traduz exceções de plugins/HTTP para erros da aplicação
  (`UserLocationException` com `UserLocationFailure`, `InvalidCodeException`,
  `RateLimitedException`).
- **State Pattern (Padrão de Estado)**. Os ViewModels emitem estados para a UI que refletem o comportamento da tela. Cada estado é uma classe abstrata com implementações concretas, e a UI observa esses estados para se comportar corretamente.
- O view model emite estados para a UI para controle de comportamento visual e interativo.
- A UI não faz chamadas diretas aos ViewModels nem serviços; ela apenas observa os estados.
- Cada fluxo deve ter estados explícitos de carregamento, sucesso, vazio e erro.

## Injeção de dependência

- As dependências compartilhadas são registradas em `lib/di/dependencies.dart`
  e resolvidas pelo `injector`. `setupDependencies()` é chamado em `main.dart`
  antes do `runApp`.
- O `CustomInjector` usa `addService` para singletons, `addRepository` para lazy
  singletons com `dispose` automático e `addViewModel` para factories. View
  models que recebem parâmetros usam `addViewModelParam` e
  `getViewModelParam`.
- As páginas resolvem seus view models pelo injetor. Elas mantêm parâmetros
  opcionais de repository/view model para permitir fakes em testes, sem
  depender do injetor.
- `ApiClient`, `SessionStorage` e `ApiAuthRepository` são registrados no
  injetor. O `AuthRepository` é a fonte de verdade da sessão e o
  `refreshListenable` do GoRouter: ao entrar ou sair, a guarda redireciona
  entre `/auth` e `/`.
- O `MapTab` aceita overrides de repository para testes; quando não há override,
  usa as dependências registradas no injetor. A `MapSearchPage` segue o mesmo
  padrão para o repositório de busca.
- Dependências com recursos (streams, controllers) são liberadas pelo
  `disposeDependencies()` ou pelo próprio widget quando ele as criou.
- Não crie novos injetores locais nem registre dependências fora de
  `lib/di/dependencies.dart`.

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
| Repository  | houver dados a expor para a UI (mesmo que venham de um service)    | contrato em `lib/domain/repositories/`; implementação em `lib/data/repositories/` |
| Use case    | a regra for reutilizada por 2+ view models ou combinar repositories | `lib/domain/` (opcional)           |
| View model  | a tela tiver estado que muda e ações a coordenar                   | `lib/ui/features/<feature>/presentation/` |
| Widget      | o trecho de UI se repetir ou a página ficar grande demais          | `lib/ui/features/<feature>/presentation/` |

## Estado atual das features

Os dados compartilhados ficam em `lib/data/`; a tabela abaixo mostra quais
deles cada funcionalidade usa. Nenhuma feature tem camada de domínio por
enquanto.

| Feature        | Presentation                                                   | Dados usados                                                                                | Domain |
| -------------- | -------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | ------ |
| auth           | e-mail e código, com view models e guarda de rota              | `AuthRepository` + `ApiAuthRepository`, `ApiClient`, `SessionStorage`                        | —      |
| home           | `HomePage` e navegação por abas                                | —                                                                                           | —      |
| home/account   | `AccountTab` e `AccountViewModel`                              | `AuthRepository` (e-mail e logout)                                                          | —      |
| home/favorites | `FavoritesTab`                                                 | —                                                                                           | —      |
| home/map       | `MapTab`, `MapLocationViewModel`, `MapTrackingViewModel`, `MapSearchViewModel`, `TrackingPanel` | `UserLocationRepository`, `TrackingRepository`, `PlaceSearchRepository`, `LocationService`, `UserCoordinates` | —      |
| line_details   | `DetailsLinePage` e `DetailsLineViewModel`                       | `DetailsLineRepository`, `LineStopsService`, `BusStopService`, `Line`, `BusStop`              | —      |
| core           | `AppColors`, `AppTheme`, `EmptyState`, `TabHeader`             | —                                                                                           | —      |

Os elementos visuais de `core` ficam em `lib/ui/core/`.

## Referências

- [Flutter — Arquitetura de aplicações](https://docs.flutter.dev/app-architecture)
- [Flutter — Guia de arquitetura](https://docs.flutter.dev/app-architecture/guide)
- [Flutter — Casos de uso (camada de domínio)](https://docs.flutter.dev/app-architecture/case-study)
