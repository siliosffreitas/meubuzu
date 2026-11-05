# AGENTS.md

Instruções para agentes de IA (opencode) que trabalham neste repositório.

## Visão geral

O MeuBuzu mostra a localização de ônibus em tempo real e ajuda o usuário a
encontrar linhas e paradas. Este repositório é um monorepo com:

- `app/`: aplicativo Flutter (Android, iOS e web).
- `backend/`: API em Dart usando o framework Vaden.

Documentação de referência:

- `README.md`: visão de produto, planos e requisitos.
- `CLAUDE.md`: regras de negócio e diretrizes gerais.
- `app/README.md`: arquitetura do app, Google Maps e localização.
- `backend/README.md`: decisões de armazenamento e backend.

## Regras rápidas

- Trabalhe no subprojeto correto: comandos Flutter são executados dentro de
  `app/`; comandos Dart do backend dentro de `backend/`.
- **Nunca** versione ou exponha segredos. As chaves do Google Maps ficam em
  `app/.env`, que é ignorado pelo git. Não imprima o conteúdo do `.env` em logs
  ou respostas.
- **Nunca** registre códigos temporários de autenticação em logs.
- Preserve as telas e a lógica de autenticação ao mexer na navegação.
- Textos de interface e comentários são em português; nomes de classes,
  variáveis e arquivos seguem o inglês já usado no projeto.
- Antes de finalizar qualquer alteração no app, rode:
  ```sh
  cd app
  flutter analyze
  flutter test
  ```
- Não edite `backend/lib/vaden_application.dart` à mão: ele é gerado pelo
  Vaden.
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
    repositories/           # contratos + implementações
    services/               # integrações externas
  domain/                   # opcional: use cases compartilhados
  ui/                       # camada de UI
    core/                   # apenas elementos visuais compartilhados
      theme/                # AppColors, AppTheme
      widgets/              # widgets compartilhados (EmptyState, TabHeader)
    routing/                # GoRouter (app_router.dart e app_routes.dart)
    features/
      auth/                 # presentation/ (e-mail e código)
      home/                 # Home com abas Mapa, Favoritos e Conta
        presentation/
          home_page.dart
          widgets/
            account/        # aba Conta
            favorites/      # aba Favoritos
            map/            # aba Mapa (views, view models e widgets)
app/test/                   # espelha a estrutura de lib/
```

Atualmente `app/lib/app.dart` inicia direto na `HomePage` para facilitar os
testes. As telas de autenticação continuam em `ui/features/auth` e a confirmação
do código navega para a Home. Não remova a autenticação ao ajustar a Home.

## Comandos

### App Flutter

```sh
cd app
flutter pub get
flutter run
flutter analyze
flutter test
dart format lib test

# Build Android
flutter build apk --debug

# Validar iOS sem assinatura
flutter build ios --no-codesign --simulator

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

```sh
cd backend
dart pub get
dart run bin/server.dart
dart analyze
dart run build_runner build --delete-conflicting-outputs
```

O backend usa PostgreSQL/PostGIS (e futuramente TimescaleDB) como fonte de
verdade. `application.yaml` contém configuração local; não versione credenciais
reais.

## Configuração das chaves do Google Maps

As chaves ficam em `app/.env`, com uma variável por plataforma:

```sh
MAPS_API_KEY_ANDROID=<chave-restrita-ao-android>
MAPS_API_KEY_IOS=<chave-restrita-ao-ios>
```

- `app/.env.example` documenta o formato. Use `cp .env.example .env` para criar
  o arquivo local.
- O Android lê `MAPS_API_KEY_ANDROID` via Gradle
  (`android/app/build.gradle.kts`); o iOS lê `MAPS_API_KEY_IOS` via xcconfig
  (`ios/Flutter/Debug.xcconfig` e `Release.xcconfig`).
- `android/local.properties` e `ios/Flutter/Secrets.xcconfig` são fallbacks
  opcionais com `MAPS_API_KEY`; não são o caminho principal.
- O `.env` precisa ficar em `app/.env` (não na raiz do repositório), pois os
  caminhos relativos dos builds nativos dependem disso.
- Cada chave deve ser restrita à sua plataforma. Não reutilize a chave Android
  no iOS nem vice-versa.

## Arquitetura e convenções do app

O app segue a arquitetura recomendada pelo Flutter, com as camadas de UI
(`presentation/`, MVVM) e de dados (`lib/data/`) separadas. Repositórios e
services ficam em `lib/data/` porque não pertencem a uma única feature:

- **Views/widgets** exibem estado e encaminham ações; não concentram regras de
  negócio.
- **ViewModels** estendem `ChangeNotifier`, mantêm estado privado, expõem
  getters e notificam a view.
- **Repositories/Services** ficam em `lib/data/repositories/` e
  `lib/data/services/`. Isolam acesso a dados e recursos de plataforma. Defina
  uma interface e uma implementação real.
- **Modelos** compartilhados ficam em `lib/data/models/`.
- O fluxo é unidirecional: view → view model → repository → service → estado →
  view.
- As rotas são gerenciadas pelo GoRouter em `ui/routing/`. A Home é a rota
  inicial (`/`) para facilitar os testes; a autenticação começa em `/auth`.
  Navegue com `context.pushNamed`/`context.goNamed`.
- Use injeção de dependência por construtor, com valor padrão, para permitir
  fakes nos testes. Exemplos: `MapTab`, `MapSearchViewModel` e
  `MapLocationViewModel`.
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
- O view model de busca do mapa usa debounce de 320 ms; em testes, avance o
  tempo com `tester.pump(Duration(...))`.
- Inclua testes de estados de carregamento, erro, vazio e sucesso ao criar
  novos fluxos.
- Rode a suíte completa antes de concluir:
  ```sh
  cd app && flutter test
  ```

## Regras de negócio que não devem regredir

- Teste gratuito de 7 dias:
  - 1 linha acompanhada por vez;
  - até 5 rastreamentos iniciados por dia;
  - 1 linha favorita.
- Assinatura paga: várias linhas, rastreamentos ilimitados, favoritos
  ilimitados e sem anúncios.
- Favoritar, desfavoritar e abrir uma linha favorita não consomem cota de
  rastreamento.
- Acesso por e-mail + código temporário de uso único e curta validade (não é
  senha permanente).
- O backend é a fonte de verdade para limites e favoritos; não confie apenas em
  contadores locais do app.
- Privacidade: explique o uso da localização antes de solicitar a permissão.

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

## Checklist de entrega

- [ ] Comportamento implementado na feature correta.
- [ ] Testes adicionados/atualizados quando houver lógica nova.
- [ ] `flutter analyze` sem problemas.
- [ ] `flutter test` passando.
- [ ] Build Android validado quando houver mudança nativa.
- [ ] Build iOS validado (`--no-codesign --simulator`) quando houver mudança
      nativa/plugin.
- [ ] Nenhum segredo, chave ou código temporário exposto.
- [ ] Documentação atualizada se configuração ou arquitetura mudou.
