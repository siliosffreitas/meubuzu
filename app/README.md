# Aplicativo MeuBuzu

## Tecnologia

O aplicativo é desenvolvido com **Flutter** e **Dart** para **Android e iOS**. Não há versão web no lançamento.

## Backend local nos testes

Enquanto a API não estiver integrada, o app usa os catálogos locais de `app/assets`. Para testar o app contra o backend Django rodando na sua máquina:

```sh
cd backend
.venv/bin/python manage.py runserver 0.0.0.0:8000
```

- **Emulador Android:** use `http://10.0.2.2:8000` (endereço do host visto de dentro do emulador) e inclua `10.0.2.2` em `DJANGO_ALLOWED_HOSTS`.
- **Simulador iOS:** use `http://127.0.0.1:8000`.
- **Celular físico:** use o IP do Mac na mesma rede Wi-Fi e inclua esse IP em `DJANGO_ALLOWED_HOSTS`.
- Em builds futuros que chamem HTTP local, o Android exige liberar *cleartext* apenas no debug; nunca no release.

Detalhes de execução, containers e segundo plano estão em `backend/README.md`.

## Acesso, cidade e planos

Comportamento alvo do produto, detalhado em `docs/PRD-backend-meubuzu.md` e `CLAUDE.md`:

- **Cidade:** Teresina-PI no lançamento. A tela de seleção de cidade aparece
  mesmo com uma única cidade ativa; a escolha é salva no backend e restaurada em
  outro dispositivo.
- **Catálogo gratuito somente leitura:** buscar linhas, ver paradas e itinerário
  não exige pagamento.
- **Teste de 7 dias:** oferecido no primeiro rastreamento, concedido pela loja
  com cartão via RevenueCat. Libera 1 linha por vez, 5 rastreamentos/dia e 1
  favorito.
- **Assinatura mensal:** várias linhas, rastreamentos e favoritos ilimitados.
- **Após o teste:** modo somente leitura, com oferta de assinatura.
- **Heartbeat:** enquanto houver rastreamento ativo, o app envia sinal a cada
  30 s para o backend manter a sessão viva.

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

### Paradas da área visível

O catálogo local de paradas fica em `assets/paradas.csv` e é lido pelo
`AssetBusStopService`. Sempre que a câmera do mapa para de mover
(`onCameraIdle`), o `MapTab` lê o retângulo visível (`getVisibleRegion`) e pede
ao `UserLocationRepository`, via `updateVisibleArea`, as paradas contidas nele.
O service filtra o catálogo por latitude/longitude, o repositório normaliza os
cantos, ignora áreas repetidas e descarta respostas antigas, e publica a lista
no stream `visibleStops`. O `MapLocationViewModel` mantém essa lista
independente da localização do usuário.

As paradas só aparecem a partir do zoom `minVisibleStopsZoom` (14,5); abaixo
disso o mapa mostra uma região grande demais, os marcadores são limpos e uma
nova consulta só acontece quando o usuário se aproxima. O mapa exibe cada
parada como um marcador: um anel pequeno na cor principal do app, com o centro
transparente e o nome da parada no canto superior direito. Os ícones são
desenhados uma vez por nome e ficam em cache. O mesmo anel (`StopRingIcon`)
identifica as paradas no itinerário da tela de detalhes da linha.

### Linhas acompanhadas

O painel flutuante na Home lista as linhas que estão no mapa. Tocar em uma
linha abre a mesma tela de detalhes usada pela busca, permitindo consultar as
paradas e remover a linha do rastreamento.

### Busca de linhas e paradas

A busca do mapa abre a tela dedicada em `/search`
(`MapSearchPage` → `MapSearchViewModel` → `AssetPlaceSearchRepository`). O
repositório consulta o `LineSearchService` no catálogo `assets/lines.csv`
(linhas por código ou nome) e o `BusStopService` no catálogo `assets/paradas.csv`
(paradas por código, denominação ou endereço). Enquanto o backend não expõe a
busca, os catálogos locais são a fonte de verdade.

Os resultados são exibidos em seções separadas: **LINHAS • N** e
**PARADAS • N**, com um resumo da quantidade no topo. As linhas são ordenadas
pelo `sgLinha` (com o `codigoLinha` como fallback). Cada linha recebe uma cor
própria, calculada a partir do `sgLinha` e do nome da linha, exibida no fundo do bloco do código.
As paradas mostram o código antes do endereço. A linha atualmente exibida no
mapa recebe o selo **Acompanhando no mapa**; o cabeçalho também reserva espaço
para a cota diária de rastreamentos quando o backend fornecer esse dado. Ao
escolher uma sugestão, a tela retorna o item e o mapa exibe o marcador. A última
busca concluída fica em `MapSearchCache`: ao reabrir `/search`, o texto e os
resultados anteriores são restaurados sem consultar o repositório novamente. O
cache é limpo ao usar “Limpar busca” ou ao encerrar a sessão.

### Posições dos ônibus (dados de exemplo)

As posições usadas no rastreamento vêm de `assets/locations/`, um CSV por dia
sem cabeçalho (`label, codigoLinha, ônibus, geradoEm, lat, long, capturadoEm`).
O `AssetTrackingService` escolhe o arquivo pelo dia da semana da consulta
(01/06/2023 foi uma quinta-feira) e devolve, para as linhas pedidas, apenas a
captura mais recente de cada ônibus na janela de 5 minutos antes da hora
consultada. A comparação é feita pela hora do relógio (não por UTC), para que o
conjunto de 2023 funcione como demonstração em qualquer data. O índice de cada
arquivo é lido uma única vez e reutilizado nas consultas seguintes.

Enquanto houver linhas acompanhadas, o `TrackingRepositoryImpl` consulta o
serviço a cada 30 segundos (e imediatamente ao adicionar uma linha). O mapa
desenha o traçado e um marcador por ônibus na mesma cor da linha; o ícone é
gerado a partir da cor exata e fica em cache, com o marcador padrão colorido
pela matiz como fallback enquanto o ícone não está pronto.

A direção do ônibus é calculada na tela a partir da captura anterior
(`TrackingBusDirections`): a primeira posição não tem seta, e qualquer
deslocamento passa a exibir uma seta na cor da linha. A seta é um marcador
próprio, ancorado no centro do ônibus, que gira em volta do selo e aponta para
o sentido do movimento em qualquer nível de zoom.

Cada nova posição recebida é animada por `TrackingBusAnimator`: o marcador sai
da posição antiga e chega à nova em 300 ms. A primeira posição de um ônibus
aparece direto no destino, e uma atualização que chega no meio da animação
recomeça a transição a partir da posição interpolada naquele momento.

A tela de detalhes também assina o `TrackingRepository`: quando a linha já está
no mapa, o cabeçalho mostra "Acompanhando no mapa" e o botão principal vira
"Remover do mapa", que encerra o rastreamento e volta para a tela anterior. Uma
linha que sai do mapa pela própria tela de detalhes tem a seleção do mapa
limpa, para a barra de busca não exibir um código que não está mais ativo.

Ao remover uma linha do rastreamento, a câmera do mapa se reenquadra: quando
não restam linhas, mostra o usuário e as paradas da área visível; quando ainda há
outras linhas, enquadra o traçado de todas as que permaneceram (com fallback
para as posições dos ônibus ou para a coordenada da linha).

## Navegação

O app usa o [GoRouter](https://pub.dev/packages/go_router) para gerenciar as
rotas. A configuração fica em `lib/ui/routing/`:

- `app_routes.dart`: caminhos e nomes das rotas.
- `app_router.dart`: criação do `GoRouter` e injeção do `AuthRepository`.

| Rota         | Nome       | Tela                                                  |
| ------------ | ---------- | ----------------------------------------------------- |
| `/`          | `home`     | `HomePage` (abas Mapa, Favoritos e Conta)             |
| `/search`    | `mapSearch` | `MapSearchPage` (busca de linhas e paradas)          |
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
