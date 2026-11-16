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

> O app ainda usa os catálogos locais de `app/assets`, então os testes do backend no emulador são feitos por `curl` ou pelo Admin até a integração da API. Quando o app passar a chamar a API via HTTP local, o Android exigirá liberar *cleartext* apenas no build de debug (por exemplo, `android:usesCleartextTraffic="true"` no `AndroidManifest.xml` de debug ou uma network security config restrita a `10.0.2.2`). Nunca libere isso no build de release.

O `runserver` é apenas para desenvolvimento: é single-process e não tem HTTPS. O deploy público usa Gunicorn (já configurado no `Dockerfile`) e faz parte da etapa M6 do PRD.

### Endpoints de autenticação

| Método | Rota | Descrição |
| --- | --- | --- |
| `POST` | `/v1/auth/request-code` | Envia código de 6 dígitos por e-mail |
| `POST` | `/v1/auth/verify-code` | Valida o código e devolve a sessão |
| `POST` | `/v1/auth/refresh` | Rotaciona o refresh token |
| `POST` | `/v1/auth/logout` | Revoga a sessão atual |
| `GET` | `/v1/me` | Conta, preferências e entitlements |
| `GET` | `/healthz` | Liveness |
| `GET` | `/readyz` | Readiness (verifica o banco) |

Erros usam Problem Details (RFC 9457, `application/problem+json`) com um campo `code` estável.

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

As posições são armazenadas como eventos de rastreamento, identificados por veículo e horário de captura, com coordenadas, velocidade, direção e `dataMode`. A tabela `tracking_latest_position` guarda a última posição por veículo para consulta rápida.

A retenção de posições é de **30 dias**. Não há uso de TimescaleDB no lançamento: particionamento por tempo e índices BRIN/GiST atendem o MVP.

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

Enquanto o acesso à API de Teresina não for liberado, os CSVs de `app/assets` alimentam apenas **staging**, com `dataMode=demo` e banner de demonstração no app. Produção recusa iniciar com dados de demonstração e exige a API da cidade.

### Gate de lançamento

Não há data de lançamento. Produção só é liberada com acesso total à API de Teresina, dual-run de 7 dias com mismatch abaixo de 1%, billing validado e checklist do PRD cumprido.
