# AGENTS.md

Instruções para agentes de IA (opencode) que trabalham neste repositório.

## Visão geral

O MeuBuzu mostra a localização de ônibus em tempo real e ajuda o usuário a
encontrar linhas e paradas. A cidade de lançamento é **Teresina-PI**, que possui
API própria de rastreamento. A cobertura seguinte é **São Paulo-SP**, com
catálogo e posições da API Olho Vivo (SPTrans) e traçados do GTFS; a cidade
nasce inativa e é liberada por comando. Este repositório é um monorepo com:

- `app/`: aplicativo Flutter (Android e iOS; sem web).
- `backend/`: API em Python + Django 5.2 LTS + DRF + PostgreSQL/PostGIS +
  Redis + Celery. O protótipo antigo em Dart/Vaden está preservado na tag
  `backend-vaden`.

Documentação de referência:

- `README.md`: visão de produto, planos e requisitos.
- `CLAUDE.md`: regras de negócio e diretrizes gerais.
- `docs/PRD-backend-meubuzu.md`: PRD do backend e decisões D1–D48 (fonte de
  verdade para backend, dados, API e billing).
- `app/README.md`: arquitetura do app, Google Maps e localização.
- `backend/README.md`: decisões de armazenamento e backend.

## Regras rápidas

- Trabalhe no subprojeto correto: comandos Flutter são executados dentro de
  `app/`; comandos do backend dentro de `backend/`.
- Consulte `docs/PRD-backend-meubuzu.md` antes de mudar contrato de API, modelo
  de dados, cotas, billing ou importação. As decisões numeradas prevalecem sobre
  suposições.
- **Nunca** trate dados de demonstração como dados reais: staging usa CSVs com
  `dataMode=demo`, exibe banner e não vai para produção. Produção exige a API de
  Teresina.
- **Nunca** versione ou exponha segredos. As chaves do Google Maps ficam em
  `app/.env`, que é ignorado pelo git. Não imprima o conteúdo do `.env` em logs
  ou respostas.
- **Nunca** registre códigos temporários de autenticação, tokens ou dados
  pessoais em logs.
- Preserve as telas e a lógica de autenticação ao mexer na navegação.
- Textos de interface e comentários são em português; nomes de classes,
  variáveis e arquivos seguem o inglês já usado no projeto.
- Antes de finalizar qualquer alteração no app, rode:
  ```sh
  cd app
  flutter analyze
  flutter test
  ```
- O `backend/` é Django; não há mais código Dart/Vaden no diretório. Consulte
  a tag `backend-vaden` apenas como referência histórica.
- Não apague arquivos não rastreados sem investigar antes (por exemplo,
  `app/ios/Podfile`, que pode ser configuração local do usuário).
- Mudanças nativas (Android/iOS) devem ser validadas também com build, não
  apenas com `flutter analyze`.

## Estrutura do app

```text
app/lib/
  app.dart                  # MaterialApp e rota inicial
  main.dart
  data/                     # camada de dados compartilhada
    models/                 # modelos imutáveis compartilhados
    repositories/           # implementações dos repositórios
    services/               # integrações externas
  di/                       # CustomInjector e registro de dependências
  domain/                   # contratos e, quando necessário, use cases
    contracts/              # Repository, Service, ViewmodelBase
    models/                 # modelos de domínio (City)
    repositories/           # contratos (classes abstratas) dos repositórios
  ui/                       # camada de UI
    core/                   # apenas elementos visuais compartilhados
      theme/                # AppColors, AppTheme
      widgets/              # widgets compartilhados (EmptyState, TabHeader)
    routing/                # GoRouter (app_router.dart e app_routes.dart)
    features/
      auth/                 # presentation/ (e-mail e código)
      city_selection/       # presentation/ (SelectCityPage e view model)
      home/                 # Home com abas Mapa, Favoritos e Conta
        presentation/
          home_page.dart
          widgets/
            account/        # aba Conta (inclui troca de cidade)
            favorites/      # aba Favoritos
            map/            # aba Mapa (views, view models e widgets)
app/test/                   # espelha a estrutura de lib/
```

O app inicia no fluxo de autenticação (`/auth`), em `ui/features/auth`, e a
confirmação do código navega para `/select-city` quando a conta ainda não tem
cidade, ou para a Home quando já tem. A guarda do GoRouter decide a rota
inicial: sem sessão válida, rotas internas vão para `/auth`; com sessão, as
rotas de autenticação vão para `/` ou `/select-city`; rotas internas sem cidade
vão para `/select-city`. A aba Conta abre `/select-city?change=1` para trocar a
cidade. Não remova a autenticação nem a seleção de cidade ao ajustar a Home.

## Comandos

### App Flutter

```sh
cd app
flutter pub get
flutter run --dart-define-from-file=.env
flutter analyze
flutter test
dart format lib test

# Build Android
flutter build apk --debug --dart-define-from-file=.env

# Validar iOS sem assinatura
flutter build ios --no-codesign --simulator --dart-define-from-file=.env

# Um teste específico
flutter test test/ui/features/home/presentation/widgets/map/map_location_view_model_test.dart
```

Emulador Android usado no desenvolvimento:

```sh
export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"
adb devices
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell monkey -p br.com.meubuzu.meubuzu \
  -c android.intent.category.LAUNCHER 1
```

O package/bundle ID é `br.com.meubuzu.meubuzu`.

### Backend

O `backend/` usa Django e roda com o ambiente virtual em `backend/.venv`:

```sh
cd backend
.venv/bin/python manage.py runserver
.venv/bin/python manage.py test
.venv/bin/python manage.py makemigrations
.venv/bin/python manage.py migrate
.venv/bin/ruff check .
.venv/bin/python manage.py check --deploy

# Celery (worker e beat em terminais separados)
.venv/bin/celery -A config worker -l info
.venv/bin/celery -A config beat -l info

# São Paulo: GTFS, API e catálogo
.venv/bin/python manage.py validate_sptrans_gtfs
.venv/bin/python manage.py check_sptrans_access --line 1012-10
.venv/bin/python manage.py import_sptrans_catalog --city sao-paulo --dry-run --limit 5
.venv/bin/python manage.py import_sptrans_catalog --city sao-paulo

# Rastreamento e partições
.venv/bin/python manage.py crawl_sptrans_positions --city sao-paulo --dry-run
.venv/bin/python manage.py crawl_sptrans_positions --city sao-paulo
.venv/bin/python manage.py maintain_tracking_partitions --dry-run

# Ativação explícita (São Paulo nasce inativa)
.venv/bin/python manage.py set_city_active sao-paulo --active
```

A infraestrutura local sobe com `docker compose up -d` (PostGIS, Redis e
Mailpit), que **não** inclui Celery. O backend usa PostgreSQL/PostGIS como fonte
de verdade, com Redis e Celery para cache, locks e tarefas. Catálogo é importado
em ciclo semanal (default) ou mensal por cidade; posições são ingeridas a cada
30 s. Sem worker e beat rodando, o `runserver` não atualiza posições e o app
mostra "Posições antigas". Em macOS local o worker precisa de `-P solo` por causa
de um erro do `prefork`/`spawn`; veja `backend/README.md`. O `.env` do Django
contém configuração local; não versione credenciais reais.

São Paulo usa a API Olho Vivo (SPTrans) para catálogo e posições e o GTFS local
apenas para traçados e lista semente. O token fica em `SPTRANS_API_TOKEN`, e os
arquivos do GTFS em `SPTRANS_GTFS_DIR` (`backend/data/gtfs/sptrans/`, ignorado
pelo git). Teresina continua no CSV de demonstração. O histórico de posições é
particionado por dia UTC e retido por **24 horas**.

Para testes no emulador Android, rode `.venv/bin/python manage.py runserver
0.0.0.0:8000`, inclua `10.0.2.2` em `DJANGO_ALLOWED_HOSTS` e acesse
`http://10.0.2.2:8000`. Simulador iOS usa `127.0.0.1`. Detalhes de execução,
segundo plano e liberação de HTTP local estão em `backend/README.md`.

## Configuração do `.env` (Maps e backend)

As chaves do Google Maps e a URL do backend ficam em `app/.env`:

```sh
MAPS_API_KEY_ANDROID=<chave-restrita-ao-android>
MAPS_API_KEY_IOS=<chave-restrita-ao-ios>

API_BASE_URL=
API_BASE_URL_ANDROID=http://10.0.2.2:8000
API_BASE_URL_IOS=http://127.0.0.1:8000
```

- `app/.env.example` documenta o formato. Use `cp .env.example .env` para criar
  o arquivo local.
- O arquivo é passado ao Flutter com `--dart-define-from-file=.env` em `run` e
  `build`. `API_BASE_URL` tem precedência; `API_BASE_URL_ANDROID` e
  `API_BASE_URL_IOS` são usadas quando ela está vazia.
- O Android lê `MAPS_API_KEY_ANDROID` via Gradle
  (`android/app/build.gradle.kts`); o iOS lê `MAPS_API_KEY_IOS` via xcconfig
  (`ios/Flutter/Debug.xcconfig` e `Release.xcconfig`).
- `android/local.properties` e `ios/Flutter/Secrets.xcconfig` são fallbacks
  opcionais com `MAPS_API_KEY`; não são o caminho principal.
- O `.env` precisa ficar em `app/.env` (não na raiz do repositório), pois os
  caminhos relativos dos builds nativos dependem disso.
- Use apenas linhas `CHAVE=valor` no `.env`: ele também é lido como xcconfig
  pelo iOS, então comentários (`#`/`//`) e valores multilinha quebram o build.
- Cada chave deve ser restrita à sua plataforma. Não reutilize a chave Android
  no iOS nem vice-versa.
- Não coloque segredos de servidor no `.env`: os valores passados com
  `--dart-define-from-file` ficam embutidos no aplicativo.

### Backend (`backend/.env`)

Variáveis novas da cobertura de São Paulo (o token nunca é versionado):

```sh
SPTRANS_API_BASE_URL=https://api.olhovivo.sptrans.com.br/v2.1
SPTRANS_API_TOKEN=
SPTRANS_API_TIMEOUT_SECONDS=30
SPTRANS_API_REQUESTS_PER_SECOND=5
SPTRANS_API_MAX_RETRIES=3
SPTRANS_GTFS_DIR=./data/gtfs/sptrans

TRACKING_LIVE_ACCESS_ENABLED=false  # true SOMENTE em staging
TRACKING_CRAWL_LOCK_SECONDS=25

TRACKING_HISTORY_ENABLED=true
TRACKING_HISTORY_RETENTION_HOURS=24
TRACKING_HISTORY_TRIM_MINUTES=60
TRACKING_HISTORY_TRIM_BATCH=50000
TRACKING_HISTORY_MAX_CAPTURE_AGE_SECONDS=600

CELERY_BROKER_URL=redis://127.0.0.1:6379/1
CELERY_RESULT_BACKEND=
CELERY_TASK_ALWAYS_EAGER=false
```

- `SPTRANS_GTFS_DIR` aponta para arquivos baixados manualmente no portal da
  SPTrans (exige login) e não versionados.
- `TrackingSource.config` e `CatalogSource.config` guardam apenas nomes de
  variáveis, nunca valores de token.
- `TRACKING_LIVE_ACCESS_ENABLED=true` só pode existir em staging. Em produção, o
  rastreamento live depende de trial/assinatura.

## Arquitetura e convenções do app

O app segue a arquitetura recomendada pelo Flutter, com as camadas de UI
(`presentation/`, MVVM) e de dados (`lib/data/`) separadas. Repositórios e
services ficam em `lib/data/` porque não pertencem a uma única feature:

- **Views/widgets** exibem estado e encaminham ações; não concentram regras de
  negócio.
- **ViewModels** estendem `ChangeNotifier`, mantêm estado privado, expõem
  getters e notificam a view.
- **Repositories** têm o contrato em `lib/domain/repositories/` e a
  implementação em `lib/data/repositories/`. **Services** ficam em
  `lib/data/services/`. Isolam acesso a dados e recursos de plataforma. Defina
  uma interface e uma implementação real.
- **Modelos** compartilhados ficam em `lib/data/models/`.
- O fluxo é unidirecional: view → view model → repository → service → estado →
  view.
- As rotas são gerenciadas pelo GoRouter em `ui/routing/`. O app inicia na
  autenticação (`/auth`); após confirmar o código, navega para a Home (`/`).
  Navegue com `context.pushNamed`/`context.goNamed`.
- Registre services, repositórios e view models compartilhados em
  `lib/di/dependencies.dart`, resolvidos pelo `CustomInjector` (auto_injector).
  `setupDependencies()` é chamado em `main.dart` antes do `runApp`.
- Mantenha injeção por construtor com parâmetros opcionais nas páginas/widgets
  para permitir fakes nos testes. Exemplos: `MapTab`, `AuthEmailPage`,
  `AuthCodePage`, `MapSearchViewModel` e `MapLocationViewModel`.
- Mantenha modelos imutáveis (`const`/`final`) sempre que possível.
- Reaproveite os tokens visuais de `ui/core/theme/app_colors.dart`
  (`AppColors.primary`, `surface`, `border`, `textPrimary` etc.) e os padrões de
  bordas arredondadas já existentes.
- Ao criar uma feature, siga a estrutura:
  ```text
  ui/features/<feature>/
    presentation/
      <feature>_page.dart ou <feature>_tab.dart
      <feature>_view_model.dart
      widgets/
  data/
    repositories/<feature>_repository.dart
    services/<feature>_service.dart
  ```
  As abas exibidas dentro da Home ficam em
  `ui/features/home/presentation/widgets/<aba>/`.

## Mapa e localização

- Mapa: `google_maps_flutter`.
- Localização: `geolocator`.
- O fluxo de localização segue esta ordem antes de mostrar o usuário:
  1. hardware de GPS;
  2. serviço de localização ligado;
  3. permissão;
  4. posição atual.
- Android: o `MainActivity` expõe o canal
  `br.com.meubuzu.meubuzu/location` com `hasGpsHardware`
  (`FEATURE_LOCATION_GPS`). As permissões `ACCESS_FINE_LOCATION` e
  `ACCESS_COARSE_LOCATION` estão no manifesto.
- iOS: a descrição `NSLocationWhenInUseUsageDescription` está no `Info.plist`.
- `myLocationEnabled` do Google Maps só deve ficar ativo quando a permissão já
  foi concedida, para evitar exceções de segurança.
- Ao voltar das configurações do sistema, revalide o estado sem abrir o diálogo
  de permissão repetidamente.
- Em testes, injete um `UserLocationRepository` fake nos view models e um
  `LocationService` fake nos testes do repositório. Não chame plugins reais
  (`geolocator`, Google Maps) em testes unitários/widget.

## Testes

- Os testes ficam em `app/test/` e espelham `app/lib/`.
- Use fakes que registram chamadas para verificar comportamento, como em
  `test/ui/features/home/presentation/widgets/map/map_location_view_model_test.dart`
  e `test/data/repositories/user_location_repository_test.dart`.
- Para telas de autenticação, use o helper `test/helpers/auth_test_helpers.dart`
  (`appWith`, `RecordingAuthRepository`, `tapVisible`).
- O view model de busca do mapa usa debounce de 1 s (`MapSearchViewModel.searchDebounce`);
  em testes, avance o tempo com `tester.pump(MapSearchViewModel.searchDebounce + ...)`.
- Inclua testes de estados de carregamento, erro, vazio e sucesso ao criar
  novos fluxos.
- Rode a suíte completa antes de concluir:
  ```sh
  cd app && flutter test
  ```

## Regras de negócio que não devem regredir

- **Catálogo gratuito somente leitura:** buscar linhas, paradas e itinerários não
  exige trial nem assinatura. Rastreamento, posições e escrita de favoritos
  exigem acesso ativo.
- **Teste de 7 dias oferecido no primeiro rastreamento**, concedido pela loja
  (App Store/Google Play) com cartão, via RevenueCat. Não iniciar trial no login
  nem no backend.
- **Teste:** 1 linha acompanhada por vez, até 5 rastreamentos iniciados por dia e
  1 linha favorita.
- **Assinatura mensal:** várias linhas, rastreamentos ilimitados, favoritos
  ilimitados e sem anúncios. Sem plano anual, sem web e sem Stripe.
- **Após o teste:** `read_only`; catálogo e favoritos existentes somente leitura,
  rastreamento bloqueado.
- **Antes do teste:** favoritar é bloqueado e abre a oferta de assinatura.
- **1 rastreamento = 1 linha acompanhada.** Duas linhas simultâneas no plano pago
  contam como dois. Fechar e reabrir a mesma linha conta como novo rastreamento.
  Retry com a mesma `Idempotency-Key` e reabertura de sessão viva não contam.
- **Cota global por conta**, com dia calculado no fuso da cidade selecionada
  (`America/Fortaleza` para Teresina). O fuso é campo da cidade, nunca constante
  no código.
- **Heartbeat de 30 s** mantém a sessão viva; sem sinal por ~120 s a sessão
  expira e libera o slot do trial.
- **Favoritar, desfavoritar e abrir uma linha favorita** não consomem cota de
  rastreamento nem substituem o limite de linhas acompanhadas.
- **Cidade explícita:** toda requisição de catálogo usa `/{citySlug}`. A
  preferência fica no backend para sincronizar entre dispositivos. O seletor de
  cidade aparece mesmo com apenas Teresina ativa.
- **Seleção de cidade no app:** a tela `/select-city` aparece uma vez após o
  login, antes da Home, e a escolha é salva em `PUT /v1/me/preferences` e na
  sessão local (`StoredAuthSession.selectedCity`). A aba Conta permite trocar a
  cidade (`/select-city?change=1`). Monte caminhos de catálogo/rastreamento com
  `ApiPaths.city(citySlug, path)`.
- **Acesso por e-mail + código temporário** de uso único e curta validade (não é
  senha permanente).
- **O backend é a fonte de verdade** para limites, favoritos, entitlements e
  cidade; não confie apenas em contadores locais do app.
- **Exclusão de conta remove todos os dados**, mas a assinatura da loja não é
  cancelada automaticamente e o trial não é reiniciado.
- **Privacidade:** explique o uso da localização antes de solicitar a permissão.

## Armadilhas conhecidas

- `.env` na raiz não é lido pelos builds; ele deve estar em `app/.env`.
- O primeiro build iOS pode rodar `pod install` e alterar
  `ios/Runner.xcodeproj/project.pbxproj`, `Runner.xcworkspace` e gerar
  `ios/Podfile.lock`. Isso é esperado ao adicionar plugins.
- `build/`, `.dart_tool/` e `ios/Pods/` são gerados; não os edite.
- O `flutter analyze` do app exclui `android/`, `ios/` e `web/`; erros nativos
  só aparecem em builds.
- Emuladores podem exigir permissão de localização e o GPS ligado via
  configurações do sistema. Para simular uma posição:
  ```sh
  adb -s emulator-5554 emu geo fix -46.6333 -23.5505
  ```
- Evite `print` no app; use `debugPrint` apenas em diagnóstico protegido por
  `kDebugMode`.
- **Fuso da cota:** nunca use `America/Sao_Paulo`, UTC ou o horário do servidor
  para calcular o dia. Use `catalog_city.timezone`.
- **Dados demo:** `dataMode=demo` só existe em staging. Se um endpoint de
  produção devolver demo, é bug crítico.
- **Alinhamento de cidade:** não crie rota de catálogo sem `{citySlug}`. A
  preferência do usuário não substitui o path. No app, use
  `ApiPaths.city(citySlug, path)` e nunca concatene a cidade manualmente.
- **Cidade no backend:** endpoints escopados por cidade devem herdar de
  `CityScopedAPIView`; os erros estáveis são `city_not_found` (404) e
  `city_inactive` (409). O seed de Teresina é uma migration
  (`catalog/0002_seed_teresina`), não um fixture manual. São Paulo é criada
  inativa por `catalog/0007_seed_sao_paulo` e só é ativada com
  `set_city_active sao-paulo --active`.
- **SPTrans:** o token fica apenas em `SPTRANS_API_TOKEN`; nunca o imprima em
  logs, comandos ou respostas. Os IDs internos (`cl`) vivem em
  `LineSourceRef` e não podem aparecer em payload público. O GTFS é usado
  somente para `shapes.txt` e lista semente de linhas; paradas e itinerários vêm
  da API.
- **Histórico de posições:** retenção de 24 h em partição diária UTC. Não
  aumente a retenção nem remova o trim sem medir disco/volume em staging. A
  falha do histórico nunca pode derrubar a atualização de `LatestPosition`.
- **Fonte por cidade:** Teresina é `csv_demo`; São Paulo é `sptrans_api`. Não
  sirva posições de uma cidade para outra nem use a flag
  `TRACKING_LIVE_ACCESS_ENABLED` em produção.
- **Billing:** o app nunca concede acesso pago; ele lê `GET /v1/me/entitlements`.
  Trial e assinatura só mudam por webhook do RevenueCat.

## Checklist de entrega

- [ ] Comportamento implementado na feature correta.
- [ ] Testes adicionados/atualizados quando houver lógica nova.
- [ ] `flutter analyze` sem problemas.
- [ ] `flutter test` passando.
- [ ] `python manage.py test` e `ruff check .` passando quando houver mudança
      no backend.
- [ ] `python manage.py makemigrations --check` sem alterações pendentes.
- [ ] OpenAPI atualizado quando o contrato mudar.
- [ ] Build Android validado quando houver mudança nativa.
- [ ] Build iOS validado (`--no-codesign --simulator`) quando houver mudança
      nativa/plugin.
- [ ] Nenhum segredo, chave ou código temporário exposto.
- [ ] Nenhum dado de demonstração fora de staging.
- [ ] Documentação atualizada se configuração ou arquitetura mudou.
