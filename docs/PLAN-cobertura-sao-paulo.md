# Plano — Cobertura de São Paulo no MeuBuzu

**Versão:** 1.0
**Data:** 21/11/2026
**Status:** Planejamento aprovado — implementação pendente
**Escopo:** backend Django + ajustes de teste no app Flutter
**Complementa:** `docs/PRD-backend-meubuzu.md` (decisões D1–D41)

> Este documento descreve como adicionar São Paulo-SP à cobertura do MeuBuzu,
> usando a API Olho Vivo (SPTrans) como fonte de catálogo e rastreamento e o
> GTFS da SPTrans como fonte dos traçados. Nenhum código foi alterado ainda.

---

## 1. Objetivo

Adicionar a cidade de **São Paulo-SP** (`sao-paulo`) à cobertura do produto,
com:

- catálogo (linhas, paradas, paradas por linha e traçados) importado
  semanalmente;
- rastreamento de veículos ingerido a cada 30 segundos;
- app consumindo **somente** o backend, nunca a SPTrans;
- isolamento total por cidade;
- nenhum identificador interno da SPTrans exposto na API pública.

---

## 2. Verificação de acesso e insumos

### 2.1 Documentação

A documentação do Olho Vivo está acessível em
`https://www.sptrans.com.br/desenvolvedores/api-do-olho-vivo-guia-de-referencia/documentacao-api/`,
com endpoints de linhas, paradas, posições, previsão, corredores e empresas.

### 2.2 API

| Verificação | Resultado |
|---|---|
| Host `https://api.olhovivo.sptrans.com.br/v2.1` | acessível |
| `GET /Linha/Buscar` sem token | `401` |
| `GET /Posicao` sem token | `401` |
| Autenticação | `POST /Login/Autenticar?token=...` + cookie de sessão |

O token de produção já está disponível com o responsável pelo produto. Ele
**nunca** é versionado nem logado.

### 2.3 GTFS

Arquivos completos em `~/Downloads/_sptrans_gtfs`:

| Arquivo | Tamanho | Conteúdo relevante |
|---|---:|---|
| `routes.txt` | 112 KB | 1.366 rotas; 1.350 do tipo ônibus (`route_type=3`) |
| `trips.txt` | 132 KB | 2.268 combinações rota + sentido |
| `shapes.txt` | 58 MB | 1.152.015 pontos; 2.268 shapes |
| `stops.txt` | 2,2 MB | 22.263 paradas |
| `stop_times.txt` | 4,8 MB | 99.076 registros |
| `frequencies.txt` | 1,6 MB | Frequências por viagem |

Descobertas que orientam o plano:

- O `route_id` do GTFS é igual ao `route_short_name` em **todas** as 1.366
  rotas, no formato `1012-10` — o mesmo código público da linha na API
  (`lt` + `-` + `tl`).
- Existe **exatamente um** `shape_id` por combinação `route_id + direction_id`
  no arquivo atual. Isso dispensa escolha de shape por viagem.
- 1.884 rotas têm os dois sentidos, 378 só o sentido `0` e 6 só o sentido `1`.
- O `stop_id` do GTFS **não** corresponde ao `cp` da API
  (ex.: GTFS `18848`, API `340015329`). Não há mapeamento direto.
- Há 459 ocorrências de parada repetida dentro de uma mesma viagem — a
  constraint atual de `LineStop` precisa ser revista.
- 16 rotas não são ônibus (`route_type` 1 e 2) e devem ser filtradas.

**Conclusão:** a API é a fonte de linhas, paradas e itinerários; o GTFS é a
fonte exclusiva dos traçados e serve como lista semente de códigos de linha.

---

## 3. Escopo

### 3.1 Entra no escopo

- Cidade `sao-paulo` (`America/Sao_Paulo`, importação semanal), criada
  **inativa**.
- Crawler de catálogo semanal: linhas, paradas, paradas por linha e traçados.
- Crawler de posições a cada 30 s.
- Fonte de rastreamento resolvida **por cidade**.
- Histórico de posições com retenção de **24 horas**.
- Ajustes de schema no catálogo (sentidos, referências de origem, execuções de
  importação).
- Testes de isolamento entre cidades e de não exposição de IDs internos.

### 3.2 Fora do escopo inicial

- Billing/entitlements reais. O rastreamento em produção continua dependente do
  gate de assinatura já previsto no PRD.
- Previsão de chegada (`/Previsao`), corredores, empresas e velocidade das vias.
- Integração com Metrô/CPTM (foco em `route_type=3`).
- Download automático do GTFS (o portal exige login).
- Seletor de sentido no app (o backend armazena os dois; o app consome o
  principal).
- Novos endpoints públicos: os existentes já são escopados por cidade.

---

## 4. Arquitetura proposta

### 4.1 Fonte de dados por cidade

Hoje a fonte é global (`TRACKING_POSITIONS_SOURCE`). Para suportar duas cidades
com fontes diferentes, ela passa a ser resolvida por cidade.

| Cidade | Catálogo | Rastreamento |
|---|---|---|
| Teresina | CSV de demonstração (`demo`) | CSV de demonstração (`csv_demo`) |
| São Paulo | API Olho Vivo + GTFS (`live`) | API Olho Vivo (`sptrans_api`) |

Novo modelo `TrackingSource` com uma fonte ativa por cidade. Sem fonte
cadastrada, mantém-se o fallback para `TRACKING_POSITIONS_SOURCE`, preservando o
comportamento e os testes atuais de Teresina.

### 4.2 Prioridade API × GTFS

| Informação | Fonte principal | Fallback |
|---|---|---|
| Linhas e metadados | API `/Linha/Buscar` | Nenhum; mantém catálogo anterior |
| Paradas | API `/Parada/BuscarParadasPorLinha` | Nenhum; nunca usar GTFS |
| Paradas por linha / itinerário | API `/Parada/BuscarParadasPorLinha` | Nenhum; mantém itinerário anterior |
| Traçado geográfico | GTFS `shapes.txt` | Nenhum; a API não possui shape |
| Posições | API `/Posicao` | Mantém última posição e marca `isStale=true` |

O GTFS também é a lista semente de códigos de linha (`routes.txt`) quando a API
não permitir enumerar todas.

### 4.3 Identificadores internos e contrato público

- `cl` (código interno da linha por sentido) **nunca** é exposto.
- `cp` (código da parada) é o código público da própria API e continua sendo o
  `code` da parada no contrato atual do app. Não é ID interno do banco.
- Código público da linha: `lt-tl` (ex.: `1012-10`), exposto como
  `boardingCode`.
- Novo modelo interno `LineSourceRef` guarda os `cl` de cada sentido; aparece
  apenas no admin.
- Testes garantem que `id`, `cl`, `externalId`, `lineId`, `stopId` e `sourceId`
  não aparecem nas respostas públicas.

### 4.4 Sentido das linhas

A API devolve dois registros por linha pública (`sl=1` e `sl=2`).

- Mesclar os dois em um único `Line` por `(city, boarding_code)`.
- Armazenar os dois sentidos em `LineStop` e `Route`
  (`direction=0` para `sl=1`, `direction=1` para `sl=2`).
- Endpoints de paradas e traçado continuam devolvendo `direction=0` por padrão.
- `?direction=1` fica disponível como evolução, sem uso no app nesta fase.
- O traçado cai para `direction=1` quando a linha só tem o sentido inverso.
- Remover a constraint única `(line, stop, direction)` de `LineStop`, mantendo
  apenas `(line, direction, sequence)`, por causa das linhas circulares.

---

## 5. Mudanças no backend

### 5.1 Dependências e Celery

Adicionar em `backend/requirements.txt`:

- `celery[redis]` (5.5+)
- `requests`
- `responses` (desenvolvimento/testes)

Criar `backend/config/celery.py` e importar o app em
`backend/config/__init__.py`.

Configuração em `settings.py`:

- `CELERY_BROKER_URL` no Redis, em DB separado do cache.
- `CELERY_TASK_ALWAYS_EAGER` para testes.
- `CELERY_TIMEZONE = "UTC"`.
- `CELERY_TASK_ACKS_LATE = True`, `CELERY_WORKER_PREFETCH_MULTIPLIER = 1`.
- `CELERY_BEAT_SCHEDULE`:
  - catálogo: segunda-feira, 06:00 UTC (03:00 em São Paulo);
  - posições: a cada 30 s, com `expires=25`;
  - manutenção de partições: diária (00:05 UTC) e trim horário (minuto 10).

Documentar worker e beat no `backend/README.md`; opcionalmente adicionar os
serviços ao `docker-compose.yml`.

### 5.2 Migrations de catálogo

- `catalog/0006_seed_sao_paulo.py`
  - `slug="sao-paulo"`, `name="São Paulo"`, `state="SP"`,
    `timezone="America/Sao_Paulo"`, centro `(-23.5505, -46.6333)`,
    `import_interval="weekly"`, `is_active=False`.
- `catalog/0007_catalog_source_metadata.py`
  - `CatalogSource`: `kind` (`csv`, `sptrans_api`, `gtfs`), `base_url`,
    `config`, `last_import_at`, `last_error_at`, `last_error_message`.
  - Novo `CatalogImportRun`: cidade, fonte, gatilho, início/fim, status,
    contadores e erros.
- `catalog/0008_line_source_ref.py`
  - `LineSourceRef`: `line`, `source`, `external_id` (o `cl`), `direction`.
  - Unique `(source, external_id)`.
- `catalog/0009_relax_line_stop_unique.py`
  - Remover a constraint `catalog_line_stop_pair_uniq`.

### 5.3 Migrations de rastreamento

O app `tracking` ainda não tem migrations. Criar:

- `TrackingSource`: cidade, tipo (`csv_demo`, `sptrans_api`), ativa, `config`
  (sem segredos — apenas o nome da variável de ambiente), `last_success_at`,
  `last_error_at`, `last_error_message`.
- `LatestPosition`: cidade, linha, fonte, `vehicle_code`, latitude, longitude,
  `captured_at`, `received_at`, `generated_at`, posição anterior, `heading`,
  acessibilidade, sentido, `data_mode`.
  - Unique `(city, vehicle_code)`.
  - Índices por cidade/linha e cidade/captura.
- `PositionHistory`: histórico com retenção de 24 h (detalhado abaixo).
- Seeds:
  - Teresina: `csv_demo` ativa.
  - São Paulo: `sptrans_api` ativa.

`LatestPosition` é o caminho crítico do app e **não** é afetado pela retenção:
uma linha por veículo, atualizada por upsert.

### 5.4 Histórico de posições com retenção de 24 h

#### Modelo

```text
PositionHistory (particionada por RANGE(captured_at), partição = 1 dia UTC)
  city_id, line_id, source_id
  vehicle_code, latitude, longitude
  captured_at, received_at
  direction, data_mode, is_accessible
  UNIQUE (city, source, vehicle_code, captured_at)
  INDEX (city, captured_at)
  INDEX (line, captured_at)
  INDEX (captured_at)              -- necessário para o trim
```

#### Retenção

Partição diária cobre `[D 00:00, D+1 00:00)` em UTC. Com **DROP puro**, a
retenção real ficaria entre 24 e 48 h. Para cumprir 24 h, o plano usa
**DROP + trim intradiário**:

- **Job diário (00:05 UTC):** cria a partição de `D+1` e dropa partições cujo
  limite superior já passou de `now() - 24 h` (na prática, `D-2`).
- **Job horário (minuto 10):** `DELETE` em lotes de 50 mil na partição de ontem,
  por `ctid`, até não sobrar linha com `captured_at < now() - 24 h`.
- Retenção efetiva: **24 a 25 h**.

Se a simplicidade operacional for priorizada, `TRACKING_HISTORY_TRIM_MINUTES=0`
desliga o trim e a retenção passa a 24–48 h, sem mudança de schema.

#### DDL

- Tabela pai criada por `migrations.RunSQL`; Django não gera DDL particionada.
- Model com `managed = False` e `db_table = "tracking_position_history"`.
- Nome das partições: `tracking_position_history_YYYYMMDD`.
- **Sem** default partition (ela impede `DROP` e esconde falha de criação).
- Unique inclui `captured_at`, que é a chave de partição — requisito do
  PostgreSQL.
- Índices declarados na tabela pai são herdados pelas partições.

#### Escrita no crawler

1. `LatestPosition` em upsert (batch) — caminho crítico.
2. `PositionHistory` em `bulk_create(..., ignore_conflicts=True)`, lotes de
   5 mil.
3. Falha no passo 2 é logada e **não** interrompe o crawl.
4. `ensure_partitions()` antes do insert: cria a partição da hora atual e a de
   amanhã se não existirem.
5. `captured_at` fora da janela de 10 min é rejeitado, para dado atrasado não
   cair em partição já agendada para `DROP`.

#### Volume estimado

| Cenário | Veículos | Linhas/dia | Partição | Pico em disco |
|---|---:|---:|---:|---:|
| Conservador | 10.000 | ~29 M | ~5–8 GB | ~15–24 GB |
| Alto | 15.000 | ~43 M | ~10–12 GB | ~25–35 GB |

O pico considera hoje + ontem (com bloat do trim) + `D-2` antes do `DROP`. O
bloat é transitório: vive apenas na partição que será dropada em até 24 h.
`autovacuum` não devolve espaço à partição antiga, porque inserts novos vão para
a partição do dia — por isso o pior caso é ~3 dias de dados.

Alavancas, em ordem: desligar o trim (24–48 h), amostragem 1:N,
`TRACKING_HISTORY_ENABLED=false`.

### 5.5 Cliente SPTrans e leitor GTFS

Novo pacote `backend/apps/integrations/sptrans/`:

- `client.py`
  - `SPTransClient` com autenticação por token, sessão com cookie, timeouts,
    retry com backoff e tratamento de `401`, `429` e `5xx`.
  - Rate limit configurável (`SPTRANS_API_REQUESTS_PER_SECOND`, padrão 5).
  - Nunca loga token nem URL de autenticação.
  - DTOs de linha, parada, posição e veículo.
- `gtfs.py`
  - Leitura de `routes.txt`, `trips.txt` e `shapes.txt`.
  - Filtro `route_type=3`.
  - Mapa `(route_id, direction_id) -> shape_id`.
  - Leitura streaming de `shapes.txt`, agrupando apenas os shapes necessários.
  - Validação de cabeçalhos, coordenadas e ordenação por `shape_pt_sequence`.
- `errors.py`
  - Token ausente/inválido, rate limit, indisponibilidade, GTFS inválido.

Comando auxiliar `validate_sptrans_gtfs --gtfs-dir ...` e comando
`check_sptrans_access` (autentica, busca uma linha, consulta `/Posicao` e
informa contagens e duração, sem imprimir o token).

### 5.6 Crawler de catálogo (semanal)

Arquivos:

- `apps/catalog/management/commands/import_sptrans_catalog.py`
- `apps/catalog/tasks.py`
- `apps/catalog/sptrans_import.py`

Fluxo:

1. Resolver cidade, fonte `sptrans-api` e diretório GTFS.
2. Adquirir lock distribuído no Redis.
3. Criar `CatalogImportRun`.
4. Autenticar na SPTrans.
5. Obter a lista de linhas:
   - descoberta por termos amplos (`0`–`9`) na API;
   - se limitada, usar `routes.txt` como lista semente.
6. Para cada código público:
   - `/Linha/Buscar?termosBusca=<codigo>` e filtro por `lt-tl` exato;
   - mesclar os dois sentidos em um `Line`;
   - upsert por `(city, boarding_code)`;
   - gravar os `cl` em `LineSourceRef`;
   - para cada `cl`, `/Parada/BuscarParadasPorLinha`;
   - upsert de paradas por `(city, code=cp)`;
   - substituir `LineStop` do sentido em transação por linha, mantendo os dados
     antigos se a API falhar.
7. Desativar (`is_active=false`) linhas da fonte que não apareceram, sem apagar.
8. Importar traçados do GTFS:
   - mapear `route_id` público para `Line`;
   - mapear `direction_id` 0/1 para `direction` 0/1;
   - upsert de `Route` por `(line, direction)`;
   - inverter o shape quando estiver no sentido oposto ao das paradas.
9. Invalidar o cache do catálogo da cidade.
10. Atualizar `CatalogSource.last_import_at` e fechar o `CatalogImportRun`.
11. Liberar o lock.

Opções: `--city sao-paulo`, `--source-slug sptrans-api`, `--gtfs-dir`,
`--dry-run`, `--limit`, `--lines`, `--skip-shapes`, `--shapes-only`.

Critérios: idempotência, falha parcial preserva o catálogo anterior, linha
ausente vira inativa, erros registrados sem interromper o restante.

### 5.7 Crawler de posições (30 s)

Arquivos:

- `apps/tracking/management/commands/crawl_sptrans_positions.py`
- `apps/tracking/tasks.py`
- `apps/tracking/crawler.py`

Fluxo:

1. Resolver a fonte ativa de São Paulo (`sptrans_api`).
2. Adquirir lock com timeout de 25 s.
3. Autenticar na SPTrans.
4. `GET /Posicao` uma vez (todos os veículos).
5. Para cada linha: `boarding_code = c`; resolver `Line` ativa da cidade.
6. Para cada veículo: `vehicle_code = p`, `captured_at = ta` (UTC),
   latitude/longitude, acessibilidade `a`, sentido `sl`.
7. Carregar `LatestPosition` da cidade e ignorar capturas iguais ou mais antigas.
8. Guardar posição anterior, calcular `heading` e fazer upsert em lote.
9. Gravar `PositionHistory` em lote (tolerante a falha).
10. Atualizar `TrackingSource.last_success_at` e contadores; em erro, atualizar
    `last_error_at` e manter as posições existentes.
11. Liberar o lock.

Critérios: executa em menos de 30 s, não sobrepõe execuções, não apaga posições
em falha, não armazena payload bruto nem token.

### 5.8 Leitura de posições no backend

Refatorar `apps/tracking/services.py` em dois caminhos:

- **CSV demo (Teresina):** mantém o replay atual, com rebase de datas e janela
  de 5 minutos.
- **SPTrans live (São Paulo):** lê `LatestPosition` e monta o payload.

O envelope público não muda: `source`, `dataMode`, `sourceStatus`, `isStale`
(por posição e por linha), `previousLatitude`, `previousLongitude`, `heading`,
`unresolvedLines`. A chave do cache de 10 s inclui o tipo de fonte.

**Acesso:** em staging, `TRACKING_LIVE_ACCESS_ENABLED=true` libera o
rastreamento sem billing. Em produção, a regra de entitlement continua valendo;
até o billing existir, o rastreamento de São Paulo fica bloqueado e o catálogo
segue funcionando.

### 5.9 Contrato público e isolamento por cidade

Nenhum endpoint novo. Os existentes já são escopados:

- `GET /v1/cities`
- `GET /v1/cities/{citySlug}/lines`
- `GET /v1/cities/{citySlug}/lines/{boardingCode}`
- `GET /v1/cities/{citySlug}/lines/{boardingCode}/stops`
- `GET /v1/cities/{citySlug}/lines/{boardingCode}/route`
- `GET /v1/cities/{citySlug}/stops`
- `GET /v1/cities/{citySlug}/stops/{stopCode}/lines`
- `GET /v1/cities/{citySlug}/positions`

Garantias:

- Toda consulta filtra `city`.
- Dados de São Paulo nunca aparecem com `citySlug=teresina` e vice-versa.
- `LineSourceRef`, `LatestPosition`, `PositionHistory`, `CatalogImportRun` e
  `TrackingSource` não são expostos.
- `Stop.code` continua sendo o `cp`; `Line.code` e `Line.external_id` não são
  expostos.
- Testes de isolamento entre cidades.

### 5.10 Admin e observabilidade

Registrar no Django Admin: `CatalogSource`, `CatalogImportRun`,
`LineSourceRef`, `TrackingSource` e `LatestPosition` (somente leitura), com
ações para disparar importação e crawl manualmente e exibição de
`last_success_at`, `last_error_at` e contadores.

Logs: cidade, fonte, duração, contadores e status. Nunca token, URL de
autenticação ou payload bruto. Alerta quando a fonte de posições ficar sem
sucesso por mais de 5 minutos.

### 5.11 Configuração (`.env.example`)

```sh
SPTRANS_API_BASE_URL=https://api.olhovivo.sptrans.com.br/v2.1
SPTRANS_API_TOKEN=
SPTRANS_API_TIMEOUT_SECONDS=30
SPTRANS_API_REQUESTS_PER_SECOND=5
SPTRANS_GTFS_DIR=./data/gtfs/sptrans

# Staging apenas. Nunca em produção.
TRACKING_LIVE_ACCESS_ENABLED=false

TRACKING_HISTORY_ENABLED=true
TRACKING_HISTORY_RETENTION_HOURS=24
TRACKING_HISTORY_PARTITION_UNIT=day
TRACKING_HISTORY_TRIM_MINUTES=60
TRACKING_HISTORY_TRIM_BATCH=50000

CELERY_BROKER_URL=redis://127.0.0.1:6379/1
CELERY_RESULT_BACKEND=
CELERY_TASK_ALWAYS_EAGER=false
```

O token nunca é versionado. `TrackingSource.config` guarda apenas o nome da
variável de ambiente.

---

## 6. GTFS local

- Copiar `~/Downloads/_sptrans_gtfs/*` para `backend/data/gtfs/sptrans/`.
- Adicionar `backend/data/gtfs/` ao `.gitignore` (o `shapes.txt` tem 58 MB).
- Em produção, montar volume ou copiar os arquivos antes da importação semanal.
- Depois da importação, os traçados ficam no banco e o arquivo não é necessário
  para o app.
- Documentar a atualização manual no portal de desenvolvedores (exige login).

---

## 7. Mudanças no app Flutter

A tela de seleção de cidade **já é dinâmica**: `ApiCityRepository` chama
`GET /v1/cities` e `SelectCityPage` renderiza o que o backend devolve. Não é
necessário hardcodar São Paulo.

Mudanças necessárias:

- Nenhuma mudança estrutural na tela.
- Testes com duas cidades garantindo Teresina e São Paulo.
- Teste de parsing de `City` com `America/Sao_Paulo`.
- Teste de busca/rastreamento com código no formato `1012-10`.
- Opcional: exibir `coverageNote` no card da cidade (“Dados: SPTrans”).

Limitação conhecida: o app mostra apenas um itinerário/traçado por linha. O
backend armazena os dois sentidos, mas o app consome `direction=0`.

---

## 8. Ativação e rollout

### 8.1 São Paulo entra inativo

- A migration cria a cidade com `is_active=False`.
- Comando `set_city_active`:
  - `manage.py set_city_active sao-paulo --active`;
  - `manage.py set_city_active sao-paulo --inactive`.
- `CatalogSource` e `TrackingSource` podem ficar ativos com a cidade inativa,
  para os dados estarem prontos quando ela for liberada.

### 8.2 Fases

**Fase 0 — Pré-requisitos**

- Configurar `SPTRANS_API_TOKEN` em `backend/.env`.
- Executar `check_sptrans_access`.
- Copiar e validar o GTFS em `backend/data/gtfs/sptrans/`.
- Adicionar `backend/data/gtfs/` ao `.gitignore`.

**Fase 1 — Schema e catálogo**

- Migrations de cidade, fontes, `LineSourceRef`, `CatalogImportRun` e ajuste de
  `LineStop`.
- Cliente SPTrans e leitor GTFS.
- Importação de traçados do GTFS.
- Importação de linhas/paradas/itinerários em `--dry-run` e depois completa em
  staging.

**Fase 2 — Rastreamento**

- `TrackingSource`, `LatestPosition` e `PositionHistory` particionada.
- Crawler de 30 s e jobs de partição/trim.
- Leitura live no backend.
- Testes em staging com `TRACKING_LIVE_ACCESS_ENABLED=true`.

**Fase 3 — Agendamento e operação**

- Celery worker/beat, locks, retries, health e admin.
- Documentação e `.env.example`.

**Fase 4 — App e produção**

- Testes do app com duas cidades e validação ponta a ponta.
- Ativar São Paulo em staging.
- Produção somente após o gate: token, termos de uso, rate limits, cobertura,
  monitoramento e retenção definida.

---

## 9. Testes

### 9.1 Backend

- Cliente SPTrans com fixtures: autenticação, reautenticação em `401`, retry em
  `429`/`5xx`, parsing de linhas, paradas e posições.
- Leitor GTFS com fixture mínimo: filtro `route_type=3`, mapa rota+sentido →
  shape, ordenação de pontos, shape ausente/invertido.
- Importação de catálogo: idempotência, merge dos sentidos, paradas e
  itinerários por sentido, desativação de linhas ausentes, falha parcial
  preserva dados, nenhum ID interno nos payloads.
- Crawler de posições: parsing de `/Posicao`, upsert da última posição, posição
  anterior e `heading`, duplicatas e capturas antigas, linha desconhecida,
  ausência de posições, lock e execução sobreposta.
- Histórico: criação de partição pelo job e sob demanda, `DROP` só com partição
  100% expirada, trim remove apenas `captured_at < now() - 24h`, trim em lotes
  idempotente, `captured_at` antigo rejeitado, `ignore_conflicts` sem
  duplicata, falha no histórico não afeta `LatestPosition`,
  `maintain_tracking_partitions --dry-run` não altera o banco.
- API: São Paulo em `/v1/cities`; catálogo de São Paulo funciona; isolamento
  entre cidades; rastreamento live com `dataMode=live` e `source=sptrans_api`;
  cache e `X-Tracking-Cache`.
- Comandos: `call_command`, `--dry-run` sem escrita,
  `makemigrations --check`.

### 9.2 App

- `select_city_page_test.dart` com duas cidades.
- `api_city_repository_test.dart` com São Paulo.
- Teste de código de linha com hífen.
- Teste de payload de rastreamento live.
- `flutter analyze` e `flutter test`.

### 9.3 Manual e carga

- Smoke test com token: uma linha e uma posição.
- Importação completa em staging.
- Contagens esperadas: ~1.350 linhas de ônibus, ~22 mil paradas, ~2.268
  traçados.
- Crawl de posições por 10 minutos; duração < 30 s.
- Medição de `pg_total_relation_size` e contagem real do histórico nas
  primeiras 24 h.
- Emulador: selecionar São Paulo, buscar `1012-10`, abrir paradas/traçado e
  rastrear um veículo.
- Confirmar que Teresina continua funcionando com CSV demo.

---

## 10. Riscos e mitigação

| Risco | Impacto | Mitigação |
|---|---|---|
| Token ausente/inválido | Sem catálogo e posições live | Pré-requisito da fase 0; `check_sptrans_access`; erro claro e health check |
| Rate limit da SPTrans | Importação lenta ou bloqueada | Rate limit configurável, backoff, retry, importação semanal |
| `/Posicao` muito grande | Crawler passa de 30 s | Upsert em lote, índices, lock e monitoramento de duração |
| Volume de histórico | Disco acima do previsto | Retenção de 24 h, trim configurável, medição em 24 h, amostragem ou desligar histórico |
| `DELETE` de trim pesado | Concorrência e bloat | Lotes por `ctid`, índice em `captured_at`, execução fora do pico |
| Partição ausente na virada do dia | Crawler falha | `ensure_partitions()` no crawler e criação de `D+1` com antecedência |
| GTFS desatualizado | Traçados divergentes | Atualização manual documentada; log de versão/data |
| `stop_id` do GTFS ≠ `cp` da API | Duplicação de paradas | API é a única fonte de paradas; GTFS só para shapes |
| Paradas repetidas em linhas circulares | Conflito de constraint | Remover unique `(line, stop, direction)`; manter sequence |
| App mostra só um sentido | Itinerário incompleto | Armazenar os dois; expor `direction=0`; evolução futura |
| Billing não implementado | Rastreamento live bloqueado em produção | Flag de staging; catálogo funciona; gate de produção |
| Termos de uso da SPTrans | Risco jurídico | Revisar termos antes de produção; atribuição nos docs/app |
| Ativação acidental em produção | Exposição prematura | Seed inativo + comando explícito + runbook |
| Worker/beat não implantados | Crawlers não rodam | Documentar e incluir no deploy |

---

## 11. Decisões tomadas

| # | Decisão |
|---|---|
| 1 | Token da API Olho Vivo já disponível. |
| 2 | Cidade `sao-paulo`, fuso `America/Sao_Paulo`, importação semanal. |
| 3 | API Olho Vivo é a fonte de linhas, paradas e itinerários; GTFS é a fonte de traçados e lista semente. |
| 4 | Os dois sentidos da API são mesclados em um único `Line`; os `cl` ficam em `LineSourceRef`. |
| 5 | Código público da linha é `lt-tl` (ex.: `1012-10`) em `boardingCode`. |
| 6 | Código público da parada continua sendo o `cp` da SPTrans. |
| 7 | Os dois sentidos são armazenados; `direction=0` é o padrão e `?direction=1` fica para o futuro. |
| 8 | A constraint única `(line, stop, direction)` de `LineStop` é removida. |
| 9 | Fonte de rastreamento por cidade: Teresina `csv_demo`, São Paulo `sptrans_api`. |
| 10 | GTFS não versionado; pasta local/volume com `SPTRANS_GTFS_DIR`. |
| 11 | São Paulo entra inativo; ativação primeiro em staging e produção após o gate. |
| 12 | Rastreamento live em staging com `TRACKING_LIVE_ACCESS_ENABLED=true`. |
| 13 | Histórico de posições com retenção de 24 h, partição diária e trim horário. |

---

## 12. Checklist de implementação

- [ ] Configurar e validar `SPTRANS_API_TOKEN`.
- [ ] Copiar e validar GTFS; definir `SPTRANS_GTFS_DIR`.
- [ ] Adicionar `backend/data/gtfs/` ao `.gitignore`.
- [ ] Adicionar `celery`, `requests` e `responses`.
- [ ] Criar `config/celery.py` e configurações de beat.
- [ ] Migration da cidade São Paulo inativa.
- [ ] Criar `LineSourceRef`, `CatalogImportRun` e ajustar `LineStop`.
- [ ] Criar `TrackingSource` e `LatestPosition`; seeds de Teresina e São Paulo.
- [ ] Criar `PositionHistory` particionada por dia, com índice em `captured_at`.
- [ ] Implementar `ensure_partitions()` e comando `maintain_tracking_partitions`.
- [ ] Implementar jobs de criação/`DROP` (diário) e trim (horário).
- [ ] Implementar cliente SPTrans e leitor GTFS.
- [ ] Implementar `check_sptrans_access` e `validate_sptrans_gtfs`.
- [ ] Implementar crawler de catálogo + comando + task.
- [ ] Implementar crawler de posições + comando + task.
- [ ] Refatorar leitura de posições para fonte por cidade.
- [ ] Garantir que nenhum ID interno seja exposto.
- [ ] Criar `set_city_active`.
- [ ] Adicionar testes de isolamento por cidade.
- [ ] Atualizar admin, logs e health.
- [ ] Atualizar `README`, PRD, AGENTS e `.env.example`.
- [ ] Rodar `ruff`, `manage.py test`, `makemigrations --check`.
- [ ] Rodar `flutter analyze` e `flutter test`.
- [ ] Medir volume real do histórico nas primeiras 24 h de staging.
- [ ] Validar staging e app ponta a ponta.
- [ ] Ativar São Paulo em staging; produção somente após o gate.

---

## 13. Referências

- `docs/PRD-backend-meubuzu.md` — decisões D1–D41, modelo de dados, API e
  importação.
- `backend/apps/catalog/models.py` — `City`, `CatalogSource`, `Line`,
  `LineStop`, `Route`, `Stop`.
- `backend/apps/catalog/services.py` — resolução por cidade, cache e consultas.
- `backend/apps/tracking/services.py` — leitura atual de posições e replay CSV.
- `backend/apps/tracking/sources.py` — fonte CSV e DTOs.
- `app/lib/ui/features/city_selection/presentation/select_city_page.dart` —
  tela dinâmica de seleção de cidade.
- API Olho Vivo:
  `https://www.sptrans.com.br/desenvolvedores/api-do-olho-vivo-guia-de-referencia/documentacao-api/`
