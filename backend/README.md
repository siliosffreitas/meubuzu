# Backend do MeuBuzu

## Tecnologia

O backend é desenvolvido em **Python 3.12+** com **Django 5.2 LTS**, **Django REST Framework**, **PostgreSQL + PostGIS**, **Redis** e **Celery**. Ele substituiu o protótipo em Dart/Vaden, preservado na tag `backend-vaden`.

As decisões completas — modelo, API, cotas, billing, importação e gate de lançamento — estão em `docs/PRD-backend-meubuzu.md`.

## Como rodar localmente

Pré-requisitos: Docker Desktop em execução, Python 3.12 e portas `5432`, `6379`, `1025`, `8025` e `8000` livres.

```sh
cd backend

# 1. Dependências de infraestrutura (PostGIS, Redis e Mailpit)
docker compose up -d

# 2. Ambiente virtual e dependências
python3.12 -m venv .venv
.venv/bin/pip install -r requirements.txt

# 3. Configuração local (nunca versione o .env)
cp .env.example .env

# 4. Banco de dados
.venv/bin/python manage.py migrate

# 5. Servidor de desenvolvimento
.venv/bin/python manage.py runserver
```

- API: `http://127.0.0.1:8000`.
- Admin: `http://127.0.0.1:8000/admin/` (crie o usuário com `manage.py createsuperuser`).
- Mailpit: `http://127.0.0.1:8025`. Com o backend de e-mail em `console` (padrão), o código aparece no terminal.
- A imagem do PostGIS roda como `linux/amd64` em Apple Silicon, via emulação.

O `docker compose` procura o `docker-compose.yml` na pasta atual. Da raiz do repositório, use `docker compose -f backend/docker-compose.yml up -d` (o mesmo vale para `ps`, `logs` e `down`).

### Containers do ambiente local

| Container | Portas | Para que serve |
| --- | --- | --- |
| `meubuzu_db` | `5432` | PostgreSQL 17 + PostGIS: fonte de verdade do backend. |
| `meubuzu_redis` | `6379` | Cache, rate limit, locks distribuídos e broker do Celery. |
| `meubuzu_mailpit` | `1025` (SMTP), `8025` (web) | Servidor SMTP falso que captura os e-mails de desenvolvimento. |

As portas são publicadas apenas em `127.0.0.1`, então os serviços não ficam acessíveis por outros dispositivos da rede local.

**`meubuzu_db`** guarda as tabelas de conta (`accounts_user`, `accounts_email_code`, `accounts_refresh_session`) e, no futuro, catálogo, paradas, linhas, itinerários, posições e favoritos com tipos geoespaciais. Os dados ficam no volume `backend_meubuzu_pgdata` e sobrevivem a `down`/`up`; só são apagados com `docker compose down -v`. É o único container obrigatório para o login funcionar.

**`meubuzu_redis`** mantém contadores de rate limit por e-mail e por IP, o cooldown entre códigos, cache e locks. Não é fonte permanente: reiniciar perde os contadores, o que é aceitável. Sem `REDIS_URL`, o Django usa `LocMemCache` — funciona em um processo, mas não em produção ou com múltiplos workers.

**`meubuzu_mailpit`** recebe e-mails na porta `1025` e os exibe em `http://127.0.0.1:8025`, sem enviar nada para caixas reais. É exclusivo de desenvolvimento. Para usá-lo em vez do console, defina `EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend` no `.env` e reinicie o `runserver`. Em produção será substituído por um provedor real.

### Rodando o servidor

Durante o desenvolvimento, use o servidor do Django:

```sh
cd backend
.venv/bin/python manage.py runserver
```

Ele recarrega sozinho ao salvar arquivos e responde em `http://127.0.0.1:8000`. Confira com:

```sh
curl http://127.0.0.1:8000/healthz
```

Para deixar em segundo plano (o processo continua após fechar o terminal):

```sh
cd backend
nohup .venv/bin/python manage.py runserver 127.0.0.1:8000 \
  > /tmp/meubuzu-api.log 2>&1 &
echo $! > /tmp/meubuzu-api.pid
```

- Logs: `tail -f /tmp/meubuzu-api.log`.
- Parar: `kill $(cat /tmp/meubuzu-api.pid)`.
- Alternativa mais confortável: rodar dentro de `tmux`.

#### Pelo VS Code

A configuração **`backend (Django)`** está em `.vscode/launch.json`. No painel **Run and Debug**, selecione-a e clique em **Play** (ou pressione `F5`). Para parar, use `Shift+F5` ou o botão quadrado vermelho.

Ela usa o Python de `backend/.venv`, roda com `cwd` em `backend/`, escuta em `0.0.0.0:8000` e passa `--noreload` para o debugger não conflitar com o autoreload. Por causa do `--noreload`, alterações no código exigem parar e iniciar de novo. É necessário ter as extensões **Python** e **Python Debugger** instaladas.

#### Acesso pelo emulador e pelo celular

`127.0.0.1` só aceita conexões da própria máquina. Para o app acessar, escute em todas as interfaces:

```sh
cd backend
.venv/bin/python manage.py runserver 0.0.0.0:8000
```

E ajuste o `.env`:

```sh
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,10.0.2.2
```

| Destino | URL do backend |
| --- | --- |
| Emulador Android | `http://10.0.2.2:8000` |
| Simulador iOS | `http://127.0.0.1:8000` |
| Celular físico na mesma rede Wi-Fi | `http://<ip-do-mac>:8000` |

No celular físico, inclua também o IP do Mac em `DJANGO_ALLOWED_HOSTS`.

> O app consulta catálogo e posições pela API (`/v1/cities/{citySlug}/...`). As posições de demonstração são lidas pelos CSVs em `backend/apps/tracking/data/locations/`, escolhidos pelo dia da semana da cidade; o app não embute esses arquivos. Para testar no emulador, o Android exige liberar *cleartext* apenas no build de debug (por exemplo, `android:usesCleartextTraffic="true"` no `AndroidManifest.xml` de debug ou uma network security config restrita a `10.0.2.2`). Nunca libere isso no build de release.

O `runserver` é apenas para desenvolvimento: é single-process e não tem HTTPS. O deploy público usa Gunicorn (já configurado no `Dockerfile`) e faz parte da etapa M6 do PRD.

### Celery (worker e beat)

O catálogo semanal, a ingestão de posições a cada 30 s e a manutenção das
partições do histórico rodam no Celery. Com Redis de pé, suba os dois processos
em terminais separados:

```sh
cd backend
.venv/bin/celery -A config worker -l info
.venv/bin/celery -A config beat -l info
```

O `runserver` não executa nenhuma dessas tarefas: **sem o worker e o beat rodando,
as posições de São Paulo ficam congeladas e o app passa a mostrar "Posições
antigas"**. O `docker compose` sobe apenas Postgres, Redis e Mailpit; o Celery
precisa ser iniciado manualmente (ou por um gerenciador de processos no deploy).

Em macOS local, use `-P solo` no worker. O pool `prefork` padrão usa `spawn` e
pode falhar com `ValueError: not enough values to unpack (expected 3, got 0)`;
em Linux/produção o padrão continua funcionando:

```sh
cd backend
.venv/bin/celery -A config worker -l info -P solo
.venv/bin/celery -A config beat -l info
```

O beat agenda:

| Tarefa | Cadência | O que faz |
| --- | --- | --- |
| `catalog-sptrans-weekly` | segunda, 06:00 UTC | Importa catálogo da API Olho Vivo + GTFS. |
| `tracking-sptrans-positions` | a cada 30 s | Lê `/Posicao` e atualiza a última posição. |
| `tracking-history-partitions-daily` | 00:05 UTC | Cria a partição de amanhã e dropa as expiradas. |
| `tracking-history-trim-hourly` | a cada hora, minuto 10 | Remove linhas com mais de 24 h. |

Cada execução usa um lock no cache (`TRACKING_CRAWL_LOCK_SECONDS`, padrão 25 s)
para não sobrepor ciclos. `CELERY_TASK_ALWAYS_EAGER=true` executa as tarefas no
próprio processo, útil em testes. Os comandos de gerenciamento equivalentes
estão documentados nas seções de catálogo e rastreamento.

#### Como verificar se o crawl está ativo

```sh
cd backend
ps aux | grep -E "celery -A config (worker|beat)" | grep -v grep
.venv/bin/celery -A config inspect active
.venv/bin/python manage.py shell -c "
from django.utils import timezone
from django.db.models import Max
from apps.tracking.models import LatestPosition, TrackingSource
print('agora', timezone.now())
print('capturada', LatestPosition.objects.filter(city__slug='sao-paulo').aggregate(Max('captured_at')))
print('fonte', TrackingSource.objects.filter(city__slug='sao-paulo').values('last_success_at', 'last_error_at', 'last_error_message').first())
"
```

O `inspect active` deve responder `1 node online`. A diferença entre `agora` e
`capturada` precisa ficar em poucos segundos; acima de
`TRACKING_STALE_AFTER_SECONDS` (padrão 120 s) o app marca as posições como
antigas. No log do beat aparece `Scheduler: Sending due task
tracking-sptrans-positions` e no log do worker `Task
apps.tracking.tasks.crawl_sptrans_positions_task[...] succeeded`. O comando
`crawl_sptrans_positions` sem `--dry-run` serve apenas para um ciclo manual de
diagnóstico; no dia a dia quem atualiza é o beat.

### Endpoints de autenticação

| Método | Rota | Descrição |
| --- | --- | --- |
| `POST` | `/v1/auth/request-code` | Envia código de 6 dígitos por e-mail |
| `POST` | `/v1/auth/verify-code` | Valida o código e devolve a sessão |
| `POST` | `/v1/auth/refresh` | Rotaciona o refresh token |
| `POST` | `/v1/auth/logout` | Revoga a sessão atual |
| `GET` | `/v1/me` | Conta, preferências e entitlements |
| `GET` | `/v1/cities` | Lista as cidades ativas |
| `GET` | `/v1/cities/{citySlug}` | Detalhe de uma cidade ativa |
| `GET` | `/v1/cities/{citySlug}/stops` | Paradas da cidade (`bbox`, `q` ou `codes`) |
| `GET` | `/v1/cities/{citySlug}/stops/{code}` | Detalhe de uma parada ativa |
| `GET` | `/v1/cities/{citySlug}/lines` | Busca de linhas (`q` ou `codes`) |
| `GET` | `/v1/cities/{citySlug}/lines/{boardingCode}` | Detalhe da linha (`sgLinha`) |
| `GET` | `/v1/cities/{citySlug}/lines/{boardingCode}/directions` | Sentidos/itinerários disponíveis da linha |
| `GET` | `/v1/cities/{citySlug}/lines/{boardingCode}/stops` | Paradas da linha na ordem do itinerário (`?direction=0|1`) |
| `GET` | `/v1/cities/{citySlug}/lines/{boardingCode}/route` | Traçado da linha (`?direction=0|1`; `route: null` se ausente) |
| `GET` | `/v1/cities/{citySlug}/stops/{code}/lines` | Linhas que passam pela parada |
| `GET` | `/v1/me/preferences` | Preferências da conta (cidade selecionada) |
| `PUT` | `/v1/me/preferences` | Define a cidade selecionada (`selectedCitySlug`) |
| `GET` | `/healthz` | Liveness |
| `GET` | `/readyz` | Readiness (verifica o banco) |

Erros usam Problem Details (RFC 9457, `application/problem+json`) com um campo `code` estável. Para cidade, os códigos são `city_not_found` (404) e `city_inactive` (409).

### Cidades e preferências

A tabela `catalog_city` (app `apps.catalog`) guarda `slug`, `name`, `state`,
`country`, `timezone`, centro (`latitude`/`longitude`), `import_interval`,
`is_active` e `coverage_note`. Teresina é criada pela migration
`catalog/0002_seed_teresina` com fuso `America/Fortaleza`.

São Paulo é criada **inativa** pela migration `catalog/0007_seed_sao_paulo`
(`slug=sao-paulo`, fuso `America/Sao_Paulo`, `import_interval=weekly`). Ela só
aparece em `GET /v1/cities` depois da ativação explícita, primeiro em staging:

```sh
cd backend
.venv/bin/python manage.py set_city_active sao-paulo --active
.venv/bin/python manage.py set_city_active sao-paulo --inactive
```

O comando invalida o cache da cidade. `CatalogSource` e `TrackingSource` podem
ficar ativas mesmo com a cidade inativa, para que catálogo e posições estejam
prontos no momento da liberação.

`GET /v1/cities` devolve apenas cidades ativas, ordenadas pelo nome. O payload é
o mesmo em todos os endpoints:

```json
{
  "slug": "teresina",
  "name": "Teresina",
  "label": "Teresina - PI",
  "state": "PI",
  "country": "BR",
  "timezone": "America/Fortaleza",
  "center": { "latitude": -5.16, "longitude": -42.79 },
  "isActive": true,
  "coverageNote": null
}
```

A preferência fica em `accounts_user_preference` (`selected_city`, `version`,
`updated_at`). `PUT /v1/me/preferences` é idempotente: só incrementa `version`
quando a cidade muda. A preferência também vem em `verify-code`, `refresh` e
`GET /v1/me` dentro de `preferences`. Endpoints de catálogo e rastreamento devem
herdar de `CityScopedAPIView` (`/v1/cities/{citySlug}/...`) para resolver a
cidade ativa antes de executar.

### Catálogo de paradas

As paradas ficam em `catalog_stop`, vinculadas a `catalog_city` e a uma
`catalog_source`. Código é único por cidade (`catalog_stop_city_code_uniq`) e a
tabela tem índices para bbox (`city`, `is_active`, `latitude`, `longitude`) e
busca textual (`city`, `search_text`, sem acentos). Teresina usa a semente da
migration `0002`; o CSV legado entra via comando (somente staging/demo, D2):

```sh
cd backend
.venv/bin/python manage.py import_stops --city teresina
.venv/bin/python manage.py import_stops --city teresina --path ../app/assets/paradas.csv --dry-run
```

O comando é idempotente por `(cidade, código)` — reexecutá-lo atualiza as
paradas existentes em vez de duplicá-las — e registra a fonte `csv-paradas` com
`dataMode=demo`. Produção deve usar a API da cidade, não este CSV.

`GET /v1/cities/{citySlug}/stops` aceita:

- `bbox=minLon,minLat,maxLon,maxLat`: limites de até 2° por eixo e 1°² de área;
- `q=...`: busca sem acentos em código, nome e endereço;
- `codes=2362,1848`: até 200 códigos, devolvidos na ordem pedida.

```json
{
  "stops": [
    {
      "code": "2362",
      "name": "T-SANTA FÉ",
      "address": "Rua B - Loteamento Mário Covas, Teresina - PI",
      "latitude": -5.165446,
      "longitude": -42.791169,
      "isActive": true,
      "dataMode": "demo",
      "updatedAt": "2026-11-17T14:00:00+00:00"
    }
  ],
  "count": 1
}
```

### Catálogo de linhas e itinerários

Linhas, paradas por linha e traçados ficam respectivamente em `catalog_line`,
`catalog_line_stop` e `catalog_route`, todos vinculados à cidade e ao catálogo
de linhas. O CSV legado entra via comando (somente staging/demo, D2):

```sh
cd backend
.venv/bin/python manage.py import_lines --city teresina --dry-run
.venv/bin/python manage.py import_lines --city teresina
```

O comando lê `app/assets/lines.csv`, `app/assets/lines_paradas.json` e
`app/assets/routes/<sgLinha>.csv`. É idempotente por `(cidade, código)`,
registra a fonte `csv-linhas` com `dataMode=demo` e invalida o cache da cidade
ao final. O JSON de paradas e os nomes dos arquivos de traçado são resolvidos
tanto por `codigoLinha` quanto por `sgLinha`. Produção deve usar a API da
cidade, não estes CSVs. Para popular o banco local de desenvolvimento, rode
antes `import_stops` (as paradas precisam existir para o itinerário).

**São Paulo (SPTrans):** o catálogo vem da API Olho Vivo, e o GTFS fornece os
traçados e a lista semente de linhas. Os arquivos do GTFS não são versionados:
copie-os para `backend/data/gtfs/sptrans/` (ou aponte `SPTRANS_GTFS_DIR`). O
token fica apenas no `.env` (`SPTRANS_API_TOKEN`).

```sh
cd backend
# 1. Valide o GTFS e o acesso à API (o token nunca é impresso)
.venv/bin/python manage.py validate_sptrans_gtfs
.venv/bin/python manage.py check_sptrans_access --line 1012-10

# 2. Importe o catálogo (dry-run primeiro)
.venv/bin/python manage.py import_sptrans_catalog --city sao-paulo --dry-run --limit 5
.venv/bin/python manage.py import_sptrans_catalog --city sao-paulo
```

A importação usa a API como fonte de linhas, paradas e itinerários e o GTFS
como fonte exclusiva dos traçados. Os dois sentidos da API viram uma única
`Line`, com `direction` 0/1; os códigos internos (`cl`) ficam em
`LineSourceRef` e nunca aparecem nos payloads públicos. `--skip-shapes` importa
só o catálogo da API; `--shapes-only` reimporta apenas os traçados. O comando é
idempotente, registra cada execução em `CatalogImportRun` e desativa (nunca
apaga) linhas ausentes na origem.

**Sentidos da linha** (`GET /v1/cities/{citySlug}/lines/{boardingCode}/directions`):
serve ao seletor de itinerário do rastreamento. Um sentido existe quando há
`Route` ou `LineStop`; a lista é vazia quando a linha não tem itinerário
cadastrado. O `hasRoute` informa se há traçado para desenhar no mapa:

```json
{
  "boardingCode": "1012-10",
  "directions": [
    {
      "value": 0,
      "label": "Terminal A → Jardim B",
      "hasRoute": true,
      "stopCount": 42
    },
    {
      "value": 1,
      "label": "Jardim B → Terminal A",
      "hasRoute": false,
      "stopCount": 43
    }
  ]
}
```

O traçado de um sentido específico é lido com
`GET /v1/cities/{citySlug}/lines/{boardingCode}/route?direction=1`. Trocar o
sentido no app altera apenas a polyline; as posições dos veículos continuam
sendo servidas por `/positions` sem filtro de sentido.

**Busca de linhas** (`GET /v1/cities/{citySlug}/lines`): exige `q` ou `codes`;
`codes` preserva a ordem recebida. Cada linha é devolvida como:

```json
{
  "boardingCode": "0001",
  "name": "POTY VELHO B. ESPERANCA VIA ACARAPE",
  "origin": "TERMINAL 1",
  "destination": "TERMINAL 1",
  "isActive": true,
  "dataMode": "demo",
  "updatedAt": "2026-11-17T14:00:00+00:00"
}
```

Os endpoints de linha aceitam somente o `sgLinha` como `{boardingCode}`; zeros
à esquerda são preservados. UUID, `codigoLinha` e aliases não resolvem linhas em
endpoints públicos e retornam `404 line_not_found`. O `codigoLinha` continua
sendo usado apenas na importação e na busca textual interna. Linhas ativas sem
`sgLinha` são bloqueadas pela migration `catalog/0005_require_line_boarding_code`.
O traçado usa coordenadas `[latitude, longitude]` na ordem do itinerário:

```json
{
  "boardingCode": "0001",
  "direction": 0,
  "coordinates": [[-5.09867, -42.784517], [-5.10007, -42.78449]],
  "updatedAt": "2026-11-17T14:00:00+00:00"
}
```

`GET /v1/cities/{citySlug}/stops/{code}/lines` aceita o `code` público da parada
e devolve as linhas ativas que passam por ela no mesmo formato da busca.

**Cache Redis:** o catálogo é servido do cache Django (`REDIS_URL`), com chave
versionada por cidade e TTL `CATALOG_CACHE_TTL_SECONDS` (padrão 300 s). A
resposta informa `X-Catalog-Cache: HIT | MISS`. A importação incrementa a versão
da cidade e invalida todas as consultas antigas de uma vez; não é necessário
varrer chaves. As chaves também incluem `CATALOG_PAYLOAD_VERSION` (hoje `2`) e
as de posições incluem `TRACKING_PAYLOAD_VERSION` (hoje `2`): ao mudar o formato
de um payload, incrementar a versão correspondente no deploy evita servir JSON
antigo com identificadores removidos até o TTL expirar. Sem Redis, o Django usa
`LocMemCache` (apenas para desenvolvimento local).

### Testes e qualidade

```sh
cd backend
.venv/bin/python manage.py test
.venv/bin/ruff check .
.venv/bin/python manage.py check --deploy
```


## Armazenamento de dados

### Cidades e catálogo

O catálogo é sempre escopado por cidade (`catalog_city`). Teresina é a cidade de lançamento, com fuso `America/Fortaleza` e ciclo de importação semanal ou mensal, configurável por cidade.

Usar **PostgreSQL** como fonte de verdade para os dados estruturados: ônibus, paradas, linhas, itinerários e trajetos. A extensão [PostGIS](https://postgis.net/) armazena e consulta coordenadas, paradas e trajetos.

A relação entre ônibus e linha muda conforme o dia ou a operação. Ela é armazenada separadamente, com período de validade, preservando o histórico.

O catálogo é **importado** da API da cidade, não editado manualmente como fonte primária. Edições do admin ficam em `catalog_admin_override` e sobrevivem ao import apenas quando marcadas como "manter esta edição". Itens ausentes na origem são desativados, nunca apagados. Aliases locais (`codigoLinha` × `sgLinha`) nunca são sobrescritos pelo import.

### Posições dos veículos

Cada cidade tem uma `TrackingSource` ativa (`tracking_source`), registrada por
migration: Teresina usa `csv_demo` e São Paulo usa `sptrans_api`. O app sempre
consulta `GET /v1/cities/{citySlug}/positions` e não escolhe a fonte.

**Teresina (demo).** `CsvDemoPositionSource` lê os CSVs históricos de
`backend/apps/tracking/data/locations/`, escolhe o arquivo pelo dia da semana no
fuso da cidade, desloca a hora lida para o dia atual e usa a janela de
`TRACKING_POSITION_WINDOW_SECONDS` (padrão: 300 s) para escolher a captura atual
de cada veículo. Para cada linha, devolve a captura mais recente de cada
veículo; `isStale` é calculado no backend com `TRACKING_STALE_AFTER_SECONDS`
(padrão: 120 s).

A janela não se aplica à coordenada anterior: o backend localiza a captura
imediatamente anterior do mesmo veículo no mesmo arquivo, mesmo que ela esteja
fora dos 5 minutos, e a envia como `previousLatitude` / `previousLongitude`
junto da posição atual. A partir dessas duas coordenadas, o backend calcula
`heading` em graus (`0` = norte, `90` = leste). Sem captura anterior, ou quando
as coordenadas são iguais, `heading` é `null` e o app não desenha a seta. O app
não calcula direção localmente.

**São Paulo (live).** O crawler lê `/Posicao` da API Olho Vivo a cada 30 s,
resolve a linha pelo `boardingCode` e grava a última posição em
`tracking_latest_position` (`LatestPosition`). A leitura do app usa essa tabela
e devolve `source=sptrans_api` e `dataMode=live`. O histórico fica em
`tracking_position_history`, uma tabela particionada por dia UTC com retenção de
**24 horas**.

O endpoint aplica um corte rígido de idade na leitura: posições cujo
`captured_at` é mais antigo que `TRACKING_LIVE_MAX_POSITION_AGE_SECONDS`
(padrão: 300 s) **não são devolvidas**, mesmo que ainda existam em
`tracking_latest_position` — o crawler não apaga veículos que pararam de
reportar. A linha sem captura recente responde `positions: []` e
`sourceStatus: no_positions`. Entre `TRACKING_STALE_AFTER_SECONDS` (padrão:
120 s) e o corte de 5 min, a posição continua sendo devolvida com
`isStale: true` e o app mostra o aviso "Posições antigas".

```sh
cd backend
# Inspeção sem escrita
.venv/bin/python manage.py crawl_sptrans_positions --city sao-paulo --dry-run
# Ciclo único (o beat já executa a cada 30 s)
.venv/bin/python manage.py crawl_sptrans_positions --city sao-paulo
# Partições e trim
.venv/bin/python manage.py maintain_tracking_partitions --dry-run
.venv/bin/python manage.py maintain_tracking_partitions
```

O crawl usa lock (`TRACKING_CRAWL_LOCK_SECONDS`, padrão 25 s) e não apaga
posições quando a fonte falha. Capturas mais antigas que
`TRACKING_HISTORY_MAX_CAPTURE_AGE_SECONDS` (padrão 600 s) não entram no
histórico. O trim horário mantém a retenção efetiva entre 24 e 25 h; com
`TRACKING_HISTORY_TRIM_MINUTES=0` o trim é desligado e a retenção fica entre 24
e 48 h. `TRACKING_HISTORY_ENABLED=false` desliga o histórico.

**Envelope comum.** A rota batch é
`GET /v1/cities/{citySlug}/positions?codes=0301,0245`, usando o `sgLinha`
(código de embarque, com zeros à esquerda; em São Paulo, `1012-10`). O alias
estrito é `GET /v1/cities/{citySlug}/lines/{sgLinha}/positions` e devolve
`404 line_not_found` quando a linha não existe; na rota batch, linhas não
resolvidas aparecem em `unresolvedLines`. `codigoLinha` e UUID não são aceitos
como parâmetro de rastreamento. O cache curto usa a chave
`TRACKING_CACHE_TTL_SECONDS` (padrão: 10 s) e o cabeçalho `X-Tracking-Cache`.

`TRACKING_LIVE_ACCESS_ENABLED=true` libera o rastreamento live sem billing
**somente em staging**. Em produção o acesso continua dependendo de
trial/assinatura; sem a flag, a fonte live responde `402 subscription_required`.

O Redis é usado como cache, rate limit, lock distribuído e broker do Celery, nunca como fonte permanente.

### Usuários e autenticação

Conta, e-mail verificado, preferência de cidade e sessões ficam no **PostgreSQL**. Códigos temporários de autenticação têm validade curta, uso único e são armazenados apenas como hash; nunca aparecem em logs. Tentativas de envio e validação são limitadas.

### Assinaturas e pagamentos

O estado da assinatura fica no **PostgreSQL**, associado à conta: provedor, loja, produto, status, tipo de período, início e fim do período, renovação e identificadores da transação.

**RevenueCat** é a fonte de verdade para iOS e Android. O trial de 7 dias é uma oferta introdutória da loja, **com cartão**; não existe trial concedido pelo backend. Compras e mudanças chegam por webhooks assinados e idempotentes. O app nunca concede acesso pago.

Assinatura **mensal apenas**: sem plano anual, sem web e sem Stripe.

O MeuBuzu não armazena números de cartão nem CVV. Apenas identificadores emitidos pela loja ou pelo provedor.

### Linhas favoritas

Favoritos ficam associados à conta no PostgreSQL (`favorites_favorite`), para aparecerem em qualquer dispositivo. Nesta entrega, qualquer usuário autenticado pode adicionar e remover linhas favoritas; os gates de trial/assinatura e o limite de 1 favorito do plano de teste descritos no PRD ainda não são aplicados, pois os entitlements reais ainda não existem.

Endpoints (token de acesso obrigatório):

- `GET /v1/favorites` — lista os favoritos agrupados por cidade: `{"cities": [{"city": {...}, "lines": [{"boardingCode", "line", "createdAt"}]}]}` (D41). A cidade aparece uma vez por grupo, sem IDs internos; os grupos vêm ordenados por cidade e, dentro de cada um, pelo código da linha (`sgLinha`/`boardingCode`, em ordem numérica quando aplicável; `sgLinha` vazio vai ao final do grupo).
- `POST /v1/favorites` — corpo `{ "boardingCode": "<sgLinha>", "citySlug": "<slug>" }`; é idempotente, valida cidade/linha como o catálogo e responde um favorito com `boardingCode`, `line`, `city` e `createdAt`.
- `DELETE /v1/favorites/{citySlug}/{boardingCode}` — remove o favorito identificado por cidade e `sgLinha`.

Favoritar, desfavoritar e abrir uma linha favorita não contam como rastreamento nem alteram a cota.

### Rastreamento e cotas

A cota é global por conta. O "dia" é calculado no fuso da cidade selecionada, definido em `catalog_city.timezone`. Cada sessão registra o dia e o fuso usados na contagem.

O app envia heartbeat a cada 30 s; sem sinal por cerca de 120 s, o backend encerra a sessão e libera o slot do trial. No trial há no máximo uma sessão ativa.

### Dados de demonstração

Enquanto o acesso à API de Teresina não for liberado, os CSVs em
`backend/apps/tracking/data/locations/` alimentam apenas **staging**, com
`dataMode=demo` e banner de demonstração no app. O acesso é liberado por
`TRACKING_DEMO_ACCESS_ENABLED` (padrão: `DEBUG`); com `DEBUG=False` e
`TRACKING_POSITIONS_SOURCE=csv_demo`, o endpoint responde `500 demo_mode_forbidden`.
Não use a fonte CSV em produção. Quando houver entitlements reais, a checagem em
`require_tracking_access` substitui o bypass de demonstração sem mudar o envelope.

São Paulo não usa CSV: a fonte é `sptrans_api`, com dados `live`. Em staging, o
rastreamento live é liberado por `TRACKING_LIVE_ACCESS_ENABLED=true`; em
produção a flag fica desligada e o acesso depende de trial/assinatura. Nunca
ative a flag live em produção. Os dados de São Paulo ficam isolados pelo slug
`sao-paulo` e não aparecem em Teresina.

### Retenção do histórico

O histórico de posições é mantido por **24 horas**, em partição diária UTC
(`tracking_position_history_YYYYMMDD`). O job diário cria a partição de amanhã e
dropa as inteiramente expiradas; o trim horário remove, em lotes, as linhas
anteriores à janela dentro da partição de fronteira. A retenção efetiva fica
entre 24 e 25 horas. Não aumente a retenção sem medir disco e volume reais em
staging.

### Gate de lançamento

Não há data de lançamento. Produção só é liberada com acesso total à API de Teresina, dual-run de 7 dias com mismatch abaixo de 1%, billing validado e checklist do PRD cumprido.
