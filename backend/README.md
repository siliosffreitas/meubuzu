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
| `meubuzu_redis` | `6379` | Cache, rate limit, locks distribuídos e, no futuro, broker do Celery. |
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
| `GET` | `/v1/cities/{citySlug}/stops/{id}` | Detalhe de uma parada ativa |
| `GET` | `/v1/cities/{citySlug}/lines` | Busca de linhas (`q` ou `codes`) |
| `GET` | `/v1/cities/{citySlug}/lines/{id}` | Detalhe da linha |
| `GET` | `/v1/cities/{citySlug}/lines/{id}/stops` | Paradas da linha na ordem do itinerário |
| `GET` | `/v1/cities/{citySlug}/lines/{id}/route` | Traçado da linha (`route: null` se ausente) |
| `GET` | `/v1/cities/{citySlug}/stops/{id}/lines` | Linhas que passam pela parada |
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
      "id": "11111111-1111-1111-1111-111111111111",
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

**Busca de linhas** (`GET /v1/cities/{citySlug}/lines`): exige `q` ou `codes`;
`codes` preserva a ordem recebida. Cada linha é devolvida como:

```json
{
  "id": "11111111-1111-1111-1111-111111111111",
  "code": "3",
  "boardingCode": "0001",
  "name": "POTY VELHO B. ESPERANCA VIA ACARAPE",
  "origin": "TERMINAL 1",
  "destination": "TERMINAL 1",
  "isActive": true,
  "dataMode": "demo",
  "updatedAt": "2026-11-17T14:00:00+00:00"
}
```

Os endpoints de linha aceitam como `{id}` o UUID canônico, o `codigoLinha`, o
`sgLinha` ou um alias local. Código ambíguo retorna `409 ambiguous_line_code`;
linha inexistente retorna `404 line_not_found`. O traçado usa coordenadas
`[latitude, longitude]` na ordem do itinerário:

```json
{
  "lineId": "11111111-1111-1111-1111-111111111111",
  "direction": 0,
  "coordinates": [[-5.09867, -42.784517], [-5.10007, -42.78449]],
  "updatedAt": "2026-11-17T14:00:00+00:00"
}
```

`GET /v1/cities/{citySlug}/stops/{id}/lines` aceita UUID ou código da parada e
devolve as linhas ativas que passam por ela no mesmo formato da busca.

**Cache Redis:** o catálogo é servido do cache Django (`REDIS_URL`), com chave
versionada por cidade e TTL `CATALOG_CACHE_TTL_SECONDS` (padrão 300 s). A
resposta informa `X-Catalog-Cache: HIT | MISS`. A importação incrementa a versão
da cidade e invalida todas as consultas antigas de uma vez; não é necessário
varrer chaves. Sem Redis, o Django usa `LocMemCache` (apenas para desenvolvimento
local).

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

Nesta fase as posições são servidas por `PositionSource`, sem tabelas de tracking. A implementação `CsvDemoPositionSource` lê os CSVs históricos de
`backend/apps/tracking/data/locations/`, escolhe o arquivo pelo dia da semana no
fuso da cidade, desloca a hora lida para o dia atual e mantém apenas capturas
dos últimos `TRACKING_POSITION_WINDOW_SECONDS` (padrão: 300 s). Para cada linha,
devolve a captura mais recente de cada veículo; `isStale` é calculado no backend
com `TRACKING_STALE_AFTER_SECONDS` (padrão: 120 s). O envelope é o mesmo que um
futuro adaptador da API de Teresina deve devolver, com `source`, `dataMode`,
`lines[]` e `unresolvedLines`.

A rota batch é `GET /v1/cities/{citySlug}/positions?codes=0301,0245`, usando o
`sgLinha` (código de embarque, com zeros à esquerda). O alias estrito é
`GET /v1/cities/{citySlug}/lines/{sgLinha}/positions` e devolve
`404 line_not_found` quando a linha não existe; na rota batch, linhas não
resolvidas aparecem em `unresolvedLines`. `codigoLinha` e UUID não são aceitos
como parâmetro de rastreamento. O cache curto usa a chave
`TRACKING_CACHE_TTL_SECONDS` (padrão: 10 s) e o cabeçalho `X-Tracking-Cache`.

Quando o crawler volátil entrar, o armazenamento previsto continua sendo eventos
por veículo e horário de captura, com coordenadas, velocidade, direção e
`dataMode`, além de `tracking_latest_position` para consulta rápida, retenção de
30 dias e índices BRIN/GiST — sem TimescaleDB no lançamento.

O Redis é usado como cache, rate limit, lock distribuído e broker do Celery, nunca como fonte permanente.

### Usuários e autenticação

Conta, e-mail verificado, preferência de cidade e sessões ficam no **PostgreSQL**. Códigos temporários de autenticação têm validade curta, uso único e são armazenados apenas como hash; nunca aparecem em logs. Tentativas de envio e validação são limitadas.

### Assinaturas e pagamentos

O estado da assinatura fica no **PostgreSQL**, associado à conta: provedor, loja, produto, status, tipo de período, início e fim do período, renovação e identificadores da transação.

**RevenueCat** é a fonte de verdade para iOS e Android. O trial de 7 dias é uma oferta introdutória da loja, **com cartão**; não existe trial concedido pelo backend. Compras e mudanças chegam por webhooks assinados e idempotentes. O app nunca concede acesso pago.

Assinatura **mensal apenas**: sem plano anual, sem web e sem Stripe.

O MeuBuzu não armazena números de cartão nem CVV. Apenas identificadores emitidos pela loja ou pelo provedor.

### Linhas favoritas

Favoritos ficam associados à conta no PostgreSQL, para aparecerem em qualquer dispositivo. Antes do trial são bloqueados; no trial, o limite é **1 linha favorita**, validado no backend, não apenas no app. Após o contrato, o limite deixa de existir; após o trial sem assinatura, os favoritos ficam somente leitura.

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

### Gate de lançamento

Não há data de lançamento. Produção só é liberada com acesso total à API de Teresina, dual-run de 7 dias com mismatch abaixo de 1%, billing validado e checklist do PRD cumprido.
