# Aplicativo MeuBuzu

## Tecnologia

O aplicativo será desenvolvido com **Flutter** e **Dart**, compartilhando a maior parte do código entre Android, iOS e web.

## Mapa (Google Maps)

A tela Home usa o Google Maps. As chaves de API **não** são versionadas e ficam
em `app/.env`, uma para cada plataforma:

```sh
cp .env.example .env
# edite .env e preencha:
MAPS_API_KEY_ANDROID=<chave-restrita-ao-android>
MAPS_API_KEY_IOS=<chave-restrita-ao-ios>
```

O mesmo arquivo `.env` é consumido pelos builds nativos de Android (Gradle) e
iOS (xcconfig). O Android usa `MAPS_API_KEY_ANDROID` e o iOS usa
`MAPS_API_KEY_IOS`, então não é necessário configurar as chaves em
`android/local.properties` nem em `ios/Flutter/Secrets.xcconfig`. Esses dois
arquivos continuam funcionando como fallback opcional (com a variável
`MAPS_API_KEY`).

Sem as chaves, o app abre normalmente, mas o mapa fica sem os blocos de ruas.

### Localização do usuário

O app verifica o hardware de GPS, o estado do serviço de localização e a
permissão, nessa ordem, antes de exibir a posição do usuário no mapa.

- **Android:** as permissões `ACCESS_FINE_LOCATION` e `ACCESS_COARSE_LOCATION`
  estão declaradas no manifesto, e o `MainActivity` expõe a checagem de GPS via
  canal nativo (`FEATURE_LOCATION_GPS`).
- **iOS:** a descrição de uso `NSLocationWhenInUseUsageDescription` está no
  `Info.plist`.

## Navegação

O app usa o [GoRouter](https://pub.dev/packages/go_router) para gerenciar as
rotas. A configuração fica em `lib/ui/routing/`:

- `app_routes.dart`: caminhos e nomes das rotas.
- `app_router.dart`: criação do `GoRouter` e injeção do `AuthRepository`.

| Rota         | Nome       | Tela                                                  |
| ------------ | ---------- | ----------------------------------------------------- |
| `/`          | `home`     | `HomePage` (abas Mapa, Favoritos e Conta)             |
| `/auth`      | `auth`     | `AuthEmailPage` (coleta do e-mail)                    |
| `/auth/code` | `authCode` | `AuthCodePage` (recebe o e-mail por `extra`)          |

O `MaterialApp.router` é montado em `lib/app.dart` e usa o router criado por
`AppRouter`.

> **Autenticação como rota inicial:** `AppRouter` define
> `initialLocation: AppRoutes.authEmail`; após confirmar o código, o app navega
> para a Home com `context.goNamed(AppRoutes.homeName)`.

Navegação entre as telas:

```dart
// Abre a confirmação de código levando o e-mail.
context.pushNamed(AppRoutes.authCodeName, extra: email);

// Volta para a Home limpando a pilha após confirmar o código.
context.goNamed(AppRoutes.homeName);
```

Em testes de widget, use `appWith` ou `appWithRoutes` de
`test/helpers/auth_test_helpers.dart` para montar um `MaterialApp.router`.

## Arquitetura

O projeto seguirá a arquitetura recomendada pela equipe do Flutter, conforme a [documentação oficial de arquitetura de aplicações](https://docs.flutter.dev/app-architecture). A organização separa responsabilidades em camadas e por funcionalidade.

O detalhamento das camadas (UI, domínio e dados), das regras de dependência, da estrutura de pastas e dos testes está em [`ARCHITECTURE.md`](./ARCHITECTURE.md).

### Camada de interface (UI)

- **Views** e widgets exibem o estado da aplicação e encaminham as interações do usuário.
- **ViewModels** mantêm e transformam o estado necessário para cada tela, coordenando as ações da interface com a camada de dados.
- Widgets devem permanecer simples, sem concentrar regras de negócio.

Essa separação segue o padrão **MVVM** (Model-View-ViewModel).

### Camada de dados

- **Repositories** são a fonte única de verdade dos dados utilizados pelo app e isolam a interface e as regras da aplicação dos detalhes de acesso aos dados.
- **Services** encapsulam integrações com fontes de dados, como a API do backend, armazenamento local e recursos da plataforma.
- Repositórios, services e modelos compartilhados ficam em `lib/data/` (com `repositories/`, `services/` e `models/`), fora de `ui/features/`, porque não pertencem a uma única funcionalidade.

### Camada de domínio

Uma camada de domínio ou casos de uso poderá ser adicionada quando houver regras de negócio complexas no cliente ou lógica compartilhada entre vários ViewModels. Ela não será criada por padrão para operações simples.

### Fluxo de dados

O fluxo será unidirecional: as Views enviam ações aos ViewModels; os ViewModels acionam os Repositories; os Repositories usam Services para acessar ou atualizar dados. O estado atualizado retorna pelo ViewModel e é exibido pela View. Os dados devem ter uma fonte única de verdade, evitando alterações independentes espalhadas pela interface.

### Princípios de implementação

- Separar a lógica de apresentação, as regras de negócio e o acesso a dados.
- Usar injeção de dependências para conectar os componentes sem dependências globais desnecessárias.
- Manter modelos de dados imutáveis sempre que apropriado.
- Testar Views, ViewModels, Repositories e Services de forma isolada e em conjunto.

O gerenciamento de estado usa `ChangeNotifier` nos ViewModels, a navegação usa
GoRouter e a injeção de dependências usa `auto_injector`, encapsulado em
`lib/di/custom_injector.dart`. As dependências compartilhadas são registradas em
`lib/di/dependencies.dart` e `setupDependencies()` é chamado antes do `runApp`.
