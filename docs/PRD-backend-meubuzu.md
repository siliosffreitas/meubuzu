# PRD — Backend do MeuBuzu

**Versão:** 1.8  
**Data:** 16/11/2026  
**Status:** Planejamento — implementação bloqueada pelo gate de acesso à API de Teresina  
**Produto:** MeuBuzu  
**Cidade de lançamento:** Teresina-PI  
**Stack decidida:** Python 3.12 + Django 5.2 LTS + DRF + PostgreSQL/PostGIS + Redis + Celery  
**Cobrança:** RevenueCat (App Store / Google Play), assinatura mensal  
**Plataformas:** Android e iOS (sem web)  
**Público:** fundador/desenvolvedor solo e futuros colaboradores

> Este é o documento único de produto e técnica do backend. As decisões numeradas (D1–D40) estão na seção 20 e prevalecem em caso de conflito com o texto corrido.

---

## Leia primeiro

1. **Não existe data de lançamento.** O app só vai para produção com **acesso total à API de Teresina**. Até lá, os CSVs de exemplo alimentam apenas **staging**.
2. **Staging é ambiente de demonstração**, não produto público: dados de exemplo, `dataMode: "demo"`, sem cobrança e sem anúncios.
3. **Catálogo gratuito somente leitura.** Buscar linhas, paradas e itinerários é aberto. Rastreamento, favoritos e posições exigem trial ou assinatura.
4. **Trial de 7 dias com cartão**, via oferta introdutória da App Store/Google Play, gerenciado pelo RevenueCat. É **oferecido no primeiro rastreamento**, mas só começa quando o usuário aceita a oferta na loja.
5. **Assinatura mensal**, sem plano anual, sem web, sem Stripe.
6. **1 rastreamento = 1 linha acompanhada.** No trial: 1 sessão por vez, até 5 rastreamentos/dia. Pago: várias linhas, sem limite.
7. **Catálogo é importado** da API da cidade em ciclo semanal (default) ou mensal. **Posições são ingeridas a cada 30 s.**
8. **Admin edita qualquer dado**, mas a importação é a fonte de verdade. A edição sobrevive ao próximo import apenas quando marcada como "manter esta edição".

---

## 1. Resumo executivo

O MeuBuzu é um aplicativo Flutter (Android e iOS) para localizar ônibus em tempo real, buscar linhas e paradas e acompanhar veículos no mapa. O app atual é um protótipo offline: os dados vêm de arquivos CSV/JSON em `app/assets` e a autenticação é simulada por `FakeAuthRepository`. O backend existente é um "hello world" em Dart/Vaden.

Este PRD define o backend de produção em **Python + Django + DRF + PostgreSQL/PostGIS**, com foco em segurança, estabilidade, confiabilidade e longevidade. O backend é a fonte de verdade para autenticação, cidades, catálogo, posições, favoritos, cotas, assinaturas e administração.

O lançamento é **Teresina-PI**, que possui API própria de rastreamento. O backend consome essa API tanto para dados cadastrais quanto para posições. Enquanto o acesso não é concedido, o desenvolvimento e a validação acontecem em **staging**, com replay dos CSVs de exemplo.

**Decisões principais:**

- Django + DRF + PostgreSQL/PostGIS + Redis + Celery.
- API REST versionada em `/v1`, contrato OpenAPI e client Dart gerado.
- Autenticação por e-mail + código OTP, JWT curto e refresh rotativo.
- Cidade explícita no path de cada requisição; preferência de cidade no backend.
- Catálogo importado periodicamente da API da cidade, com edição administrativa rastreável.
- Posições sincronizadas a cada 30 s, com frescura explícita e sem inventar dados.
- Sessões de rastreamento com heartbeat e expiração automática.
- Trial de 7 dias via loja (com cartão) e assinatura mensal via RevenueCat.
- Catálogo gratuito somente leitura; rastreamento e favoritos pagos.
- Admin Django para operação, com override auditado sobre dados importados.
- Substituição do backend Dart/Vaden, preservando o estado atual em branch/tag.
- Monorepo mantido, com CI separado por path.

---

## 2. Contexto e problema

### 2.1 Situação atual

- O app Flutter funciona com dados locais:
  - `app/assets/lines.csv`
  - `app/assets/paradas.csv`
  - `app/assets/lines_paradas.json`
  - `app/assets/routes/<sgLinha>.csv`
  - `app/assets/locations/positions_YYYY_MM_DD.csv`
- O fluxo de autenticação usa `FakeAuthRepository`; não existe autenticação real.
- O backend em `backend/` tem apenas `/hello` e `/hello/ping`, configuração de PostgreSQL e dependências do Vaden.
- As regras de negócio estão documentadas em `README.md` e `CLAUDE.md`, mas não são aplicadas no servidor.
- O app não tem seletor de cidade, paywall, trial nem controle de cotas.

### 2.2 Problema

O protótipo não consegue:

- autenticar usuários com segurança;
- servir catálogo atualizado sem novo build do app;
- receber e distribuir posições em tempo real;
- suportar mais de uma cidade;
- aplicar cotas, limites e entitlements de forma consistente entre dispositivos;
- validar assinaturas e liberar acesso pago;
- operar dados importados com segurança e rastreabilidade;
- garantir disponibilidade, observabilidade e recuperação de falhas.

### 2.3 Oportunidade

Criar uma base de backend previsível e bem documentada, capaz de lançar o MeuBuzu em Teresina com a API oficial, integrar novas cidades depois sem reescrever a fundação e sustentar um modelo de assinatura simples.

### 2.4 Restrição externa

O acesso à API de Teresina está em solicitação. **Não há data oficial de lançamento.** O desenvolvimento avança em staging; a produção depende do cumprimento integral do gate descrito na seção 5.4.

---

## 3. Objetivos e não objetivos

### 3.1 Objetivos

| ID | Objetivo | Métrica de sucesso |
|---|---|---|
| G1 | Autenticar com e-mail + código temporário | Fluxo completo com entrega, expiração, uso único e rate limit |
| G2 | Servir catálogo por cidade | App busca e exibe dados da API sem assets locais |
| G3 | Distribuir posições atuais dos veículos | Posições com `capturedAt`, `generatedAt`, `source`, `dataMode` e `isStale` |
| G4 | Aplicar cotas, limites e entitlements no servidor | 100% de consistência sob concorrência |
| G5 | Validar trial e assinatura | Webhooks idempotentes e acesso pago correto |
| G6 | Sincronizar cidade entre dispositivos | Preferência restaurada em novo login |
| G7 | Operar o produto com segurança | Admin, auditoria, backups, alertas e runbooks |
| G8 | Reduzir risco de tecnologia | Stack com comunidade grande, documentação e contratação fácil |

### 3.2 Não objetivos do MVP

- Planejador de viagem multimodal.
- Previsão de chegada por parada.
- Alertas de interrupção e notificações push.
- Histórico analítico de posições para o usuário final.
- WebSockets ou streaming em tempo real (polling no MVP).
- Múltiplas cidades no lançamento (apenas Teresina ativa).
- App web, loja web, pagamento web ou Stripe.
- Plano anual, cupons ou programa de fidelidade.
- App administrativo nativo (Django Admin cobre o MVP).
- Machine learning, previsão ou otimização de frota.
- Dashboard analítico de produto.

### 3.3 Métricas de produto a acompanhar

Funil de acesso: `catalog_only` → `trial` → `paid`.

- Contas criadas e contas que iniciaram trial.
- Conversão trial → assinatura.
- Rastreamentos por usuário/dia.
- Buscas com resultado × buscas vazias.
- Linhas abertas e favoritos por usuário.
- Retenção D1, D7 e D30.
- Churn e cancelamentos.
- Erros por código e tickets de suporte.

---

## 4. Personas e atores

| Ator | Necessidade |
|---|---|
| **Visitante autenticado** | Entrar com e-mail, escolher cidade, buscar linhas e paradas, ver itinerário sem pagar |
| **Assinante em trial** | Acompanhar 1 linha por vez, 5 rastreamentos/dia, 1 favorito |
| **Assinante pago** | Acompanhar várias linhas, favoritos ilimitados, sem anúncios |
| **Pós-trial** | Continuar consultando catálogo em modo somente leitura e assinar |
| **Operação/Admin** | Gerenciar cidades, catálogo, overrides, importações, usuários e assinaturas; auditar |
| **Fonte de dados** | Fornecer catálogo e posições de forma autenticada, idempotente e monitorável |
| **Loja / RevenueCat** | Gerenciar trial, cobrança, renovação, cancelamento e reembolso |
| **Sistema** | Aplicar cotas, expirar códigos e sessões, importar catálogo, monitorar e alertar |

---

## 5. Escopo do MVP

### 5.1 Incluído

- Autenticação por e-mail + OTP.
- Sessões com JWT e refresh rotativo.
- Cidades e preferência de cidade sincronizada.
- Perfil, entitlements e estado de acesso.
- Catálogo de linhas, paradas e rotas por cidade.
- Busca textual e geográfica.
- Importação periódica de catálogo.
- Posições atuais dos veículos.
- Sessões de rastreamento com heartbeat e cotas.
- Favoritos com limites por plano.
- Trial de 7 dias via loja e assinatura mensal via RevenueCat.
- Webhooks de billing.
- Modo somente leitura após o trial.
- Exclusão de conta e direitos LGPD.
- Admin Django com override auditado.
- Ambientes local, staging e produção, com `dataMode` explícito.
- Ingestão com adaptador de demonstração e adaptador real.
- OpenAPI e client Dart.
- Observabilidade, backups e CI/CD.

### 5.2 Fora do MVP

- WebSockets/streaming.
- Push notifications.
- Previsão de chegada.
- Planejador de viagem.
- Alertas operacionais.
- Cache offline premium no app.
- Dashboard analítico.
- Multi-cidade simultânea e multi-tenant self-service.
- Plano anual, cupons, testes A/B de preço.
- App web e pagamento fora das lojas.

### 5.3 Ambientes

| Ambiente | Dados | Cobrança | Acesso | Deploy |
|---|---|---|---|---|
| **Local** | Seed + CSV | Nenhuma | Desenvolvedor | Docker Compose |
| **Staging** | CSV de exemplo, `dataMode=demo` | Nenhuma | Testadores internos (TestFlight / Google internal testing) | Automático em PR |
| **Produção** | API de Teresina, `dataMode=live` | RevenueCat | Público | Tag, após gate |

Regras de ambiente:

- Bancos, Redis, segredos e monitoramento **separados** por ambiente.
- Staging pode ser resetado a qualquer momento.
- Produção nunca aceita `dataMode=demo`; a inicialização falha se a flag estiver ligada.
- Build de staging exibe banner permanente "Dados de demonstração".

### 5.4 Gate de lançamento em produção

Produção só é liberada quando **todos** os itens estiverem verdadeiros:

**Acesso à API de Teresina**

- [ ] Autorização formal de uso da API.
- [ ] Credenciais de produção e de teste.
- [ ] Documentação completa: endpoints, campos, formatos e exemplos.
- [ ] Rate limits conhecidos e compatíveis com sync de 30 s.
- [ ] Frequência de atualização adequada ao produto.
- [ ] Cobertura mínima aceitável (≥ 90% das linhas de Teresina).
- [ ] Qualidade validada: coordenadas, timestamps e identificação de veículo.
- [ ] Termos de uso permitindo uso comercial e armazenamento dos dados derivados.
- [ ] Contato de suporte e processo para incidentes.
- [ ] Revisão jurídica e de privacidade concluída.
- [ ] Teste ponta a ponta bem-sucedido em staging.

**Produto e operação**

- [ ] Catálogo importado e consistente por pelo menos dois ciclos.
- [ ] Dual-run CSV × API por 7 dias, com mismatch < 1%.
- [ ] Comportamento de falha validado: API fora do ar → última posição com `isStale=true`.
- [ ] Testes de carga e concorrência aprovados.
- [ ] Monitoramento, alertas, backups e restauração testados.
- [ ] Trial, paywall, restore, cancelamento e expiração testados em sandbox e produção.
- [ ] Termos, privacidade e requisitos das lojas revisados.
- [ ] App review aprovado.

**Sem todos os itens não há lançamento.** O prazo é consequência do gate, não uma data fixa.

---

## 6. Stack e decisões de arquitetura

### 6.1 Stack escolhida

| Camada | Escolha | Justificativa |
|---|---|---|
| Linguagem | Python 3.12+ | Comunidade enorme, fácil de aprender, ecossistema maduro |
| Framework | Django 5.2 LTS + DRF | ORM, migrations, auth, admin e segurança nativos |
| Banco | PostgreSQL 17 + PostGIS | Relacional, geoespacial, maduro e amplamente suportado |
| Cache/fila | Redis + Celery | Cache, rate limit, locks e tarefas assíncronas |
| Auth | OTP + JWT | Simples para o usuário, seguro e stateless para a API |
| Pagamentos | RevenueCat (IAP) | Trial e assinatura mensal sem validar recibo no backend |
| Admin | Django Admin | Ferramenta operacional pronta, com override e auditoria |
| Deploy | Docker + Fly.io (GRU) ou AWS `sa-east-1` | Simples para solo, latência baixa no Brasil |
| Observabilidade | Sentry + logs estruturados + métricas + uptime | Diagnóstico rápido e alertas |

### 6.2 Alternativas consideradas

| Alternativa | Prós | Contras | Decisão |
|---|---|---|---|
| **NestJS + TypeScript** | Tipagem estática, estrutura parecida com Vaden, comunidade enorme | Mais peças para montar (ORM, auth, admin) | Boa segunda opção |
| **Dart + Vaden** | Mesma linguagem do app, compartilhamento de modelos | Comunidade pequena, ecossistema jovem, poucos casos de produção | Não recomendado para produção |
| **Go** | Performance, deploy simples | Mais código para CRUD/auth, menos "baterias" | Não para o perfil atual |
| **Spring Boot** | Maturidade e comunidade enterprise | Pesado e verboso para solo | Não para o perfil atual |

### 6.3 ADRs

- **ADR-001:** adotar Django + DRF como framework de backend.
- **ADR-002:** adotar PostgreSQL + PostGIS como banco principal e fonte de verdade.
- **ADR-003:** autenticação por OTP + JWT com refresh rotativo.
- **ADR-004:** ingestão de posições por adaptador plugável.
- **ADR-005:** RevenueCat como fonte de verdade de trial e assinatura mobile.
- **ADR-006:** API versionada e contrato OpenAPI.
- **ADR-007:** polling no MVP; WebSocket apenas se necessário.
- **ADR-008:** cidade explícita no path; preferência de cidade no backend apenas como default e sincronização.
- **ADR-009:** trial concedido pela loja (oferta introdutória com cartão), nunca pelo backend.
- **ADR-010:** catálogo importado em ciclo configurável por cidade, com override administrativo por campo.
- **ADR-011:** sessões de rastreamento com heartbeat e expiração automática.
- **ADR-012:** nenhum dado de demonstração em produção; `dataMode` é obrigatório em toda resposta de posição.

---

## 7. Arquitetura do sistema

```text
Flutter (Android / iOS)
        │ HTTPS + OpenAPI + Bearer token
        ▼
API Django/DRF ────────────── Redis (cache, rate limit, locks, broker)
   │
   ├── PostgreSQL + PostGIS
   │     ├── cidades, contas, preferências, favoritos, sessões, assinaturas
   │     ├── importações, overrides, linhas, paradas, itinerários
   │     └── posições dos veículos (particionadas por tempo)
   │
   ├── Celery worker + beat
   │     ├── import de catálogo (semanal/mensal por cidade)
   │     ├── ingestão de posições (30 s)
   │     ├── expiração de OTP e de sessões de rastreamento
   │     ├── webhooks do RevenueCat
   │     └── limpeza, retenção e exclusão de conta
   │
   ├── Django Admin (operação, override e auditoria)
   ├── Provedor de e-mail (OTP)
   └── RevenueCat (webhooks assinados)
        ▲
        │ import de catálogo + posições
   API da cidade (Teresina) ou CSVs de demonstração (staging)
```

### 7.1 Componentes

| Componente | Responsabilidade |
|---|---|
| API | Endpoints REST, autenticação, validação, regras de negócio |
| PostgreSQL/PostGIS | Fonte de verdade relacional e geoespacial |
| Redis | Cache de posições, rate limiting, locks distribuídos, broker |
| Celery worker | Import de catálogo, ingestão, e-mails, webhooks, limpeza |
| Celery beat | Agendamento de import, ingestão e expirações |
| Django Admin | Operação de catálogo, overrides, fontes, usuários e assinaturas |
| Provedor de e-mail | Entrega de OTP com SPF/DKIM/DMARC |
| RevenueCat | Trial, assinatura, renovação e entitlements |
| Sentry/logs/métricas | Observabilidade e alertas |

### 7.2 Pipelines independentes

| Pipeline | O que traz | Frequência | Fonte |
|---|---|---|---|
| **Catálogo** | linhas, paradas, itinerários, trajetos, código de embarque | semanal (default) ou mensal, por cidade | import da API da cidade |
| **Posições** | localização dos veículos | 30 s (configurável) | API de tempo real da cidade |
| **Aliases e metadados locais** | apelidos, observações, acessibilidade, visibilidade, ordem editorial | nunca importados | admin/app |

Separar os pipelines evita que um import de catálogo apague aliases locais e evita que a frequência de posições dependa do cadastro.

### 7.3 Níveis de acesso

| Estado | Catálogo | Favoritos | Posições / rastreamento |
|---|---|---|---|
| `catalog_only` | Leitura | Bloqueado | Bloqueado; oferece trial |
| `trial` | Leitura | 1, com edição | 1 sessão ativa; 5 rastreamentos/dia |
| `paid` | Leitura | Ilimitados | Várias sessões; ilimitado |
| `read_only` | Leitura | Somente leitura | Bloqueado; paywall persistente |

Regras:

- `catalog_only` e `read_only` são gratuitos e não exigem meio de pagamento.
- `trial` só existe com assinatura em período introdutório ativa na loja.
- O app nunca concede acesso sozinho; sempre lê `GET /v1/me/entitlements`.
- `read_only` não consome cota.

### 7.4 Ambientes e flags

| Flag | Local | Staging | Produção |
|---|---|---|---|
| `DATA_MODE` | `demo` | `demo` | `live` |
| `BILLING_ENABLED` | `false` | `false` | `true` |
| `PUBLIC_LAUNCH` | `false` | `false` | `true` (após gate) |

Produção recusa inicializar com `DATA_MODE=demo` ou `BILLING_ENABLED=false`.

---

## 8. Requisitos funcionais

### RF-001 — Solicitar código de acesso

**Descrição:** o usuário informa o e-mail e recebe um código temporário de 6 dígitos.

**Regras:**

- Normalizar e validar o e-mail.
- Responder `202 Accepted` sempre, sem revelar se o e-mail já existe.
- Gerar código aleatório de 6 dígitos.
- Armazenar apenas o hash Argon2id.
- Validade padrão: 10 minutos.
- Uso único.
- Invalidar códigos anteriores ainda válidos do mesmo e-mail.
- Rate limit por e-mail, IP e dispositivo: 5/hora por e-mail e 20/hora por IP.
- Cooldown de reenvio de 60 segundos.
- Nunca registrar o código em logs, traces ou e-mails de erro.
- Enviar e-mail transacional com remetente e domínio configurados.

**Critérios de aceite:**

- E-mail novo e existente retornam `202`.
- Código chega em até 60 segundos em condições normais.
- Código não aparece em logs.
- Excesso de solicitações retorna `429` com `Retry-After`.
- Código expirado não pode ser usado.

---

### RF-002 — Verificar código e autenticar

**Descrição:** o usuário confirma o código e recebe tokens de acesso.

**Regras:**

- Comparar o código com o hash em tempo constante.
- Verificar expiração, consumo e tentativas; máximo de 5 tentativas.
- Criar usuário na primeira verificação bem-sucedida e marcar e-mail como verificado.
- **Não iniciar trial na autenticação.** O trial começa na loja (RF-012).
- Emitir access token curto (15 min) e refresh token rotativo (30 dias).
- Retornar perfil, `preferences` e `entitlements` na mesma resposta, evitando chamadas extras no login.
- Usuário novo recebe `accessLevel = "catalog_only"` e `selectedCity = null`.

**Critérios de aceite:**

- Código válido retorna tokens, usuário, preferência e entitlements.
- Código inválido, expirado ou já usado retorna `401` com código estável.
- Após 5 tentativas inválidas, novas tentativas são bloqueadas temporariamente.
- Usuário novo **não** entra em trial.
- Login em segundo dispositivo retorna a cidade já escolhida.

---

### RF-003 — Renovar sessão e sair

**Descrição:** renovar o access token e revogar sessões.

**Regras:**

- Refresh token rotativo: cada uso gera um novo e invalida o anterior.
- Detectar reuso de refresh token e revogar a família de sessões.
- Armazenar apenas hash do refresh token.
- Logout revoga a sessão atual.
- Suportar revogação por dispositivo.

**Critérios de aceite:**

- Refresh válido retorna novo par de tokens.
- Reuso de token revogado retorna `401` e invalida a família.
- Logout impede novos refreshes daquela sessão.

---

### RF-004 — Perfil, preferências e entitlements

**Descrição:** consultar dados da conta, cidade selecionada e limites efetivos.

**Regras:**

- `GET /v1/me` retorna e-mail, status da conta e cidade selecionada.
- `GET /v1/me/entitlements` retorna:

```json
{
  "accessLevel": "trial",
  "isPaid": false,
  "isTrial": true,
  "trialEndsAt": "2026-11-23T12:00:00Z",
  "subscriptionEndsAt": "2026-11-23T12:00:00Z",
  "willRenew": true,
  "managementUrl": "https://apps.apple.com/account/subscriptions",
  "maxActiveLines": 1,
  "maxFavorites": 1,
  "dailyTrackingLimit": 5,
  "trackingUsedToday": 2,
  "trackingRemainingToday": 3,
  "canTrack": true,
  "canViewPositions": true,
  "canManageFavorites": true,
  "quotaDate": "2026-11-16",
  "quotaTimezone": "America/Fortaleza"
}
```

- `accessLevel` ∈ `catalog_only`, `trial`, `paid`, `read_only`.
- `maxActiveLines`, `maxFavorites` e `dailyTrackingLimit` são `null` quando ilimitados.
- Não expor dados de cartão, recibos ou identificadores sensíveis.
- `quotaDate` e `quotaTimezone` permitem ao app explicar quando a cota reinicia.

**Critérios de aceite:**

- Conta nova retorna `catalog_only`, `canTrack=false` e nenhum limite consumido.
- Trial ativo retorna 1 sessão ativa, 1 favorito e 5 rastreamentos/dia.
- Pago retorna `paid` com limites `null`.
- Trial expirado retorna `read_only` com `canTrack=false` e `canViewPositions=false`.
- Período de graça retorna `paid` com aviso de cobrança pendente.

---

### RF-005 — Buscar linhas

**Descrição:** buscar linhas por código, nome ou código de embarque dentro de uma cidade.

**Regras:**

- Rota sempre com cidade explícita: `GET /v1/cities/{citySlug}/lines`.
- Cidade inexistente retorna `404 city_not_found`; inativa retorna `409 city_inactive`.
- Busca textual normalizada (sem acentos, case-insensitive) com `pg_trgm`.
- Considerar `codigoLinha`, `sgLinha`, aliases e nome.
- Suportar busca por proximidade (`near` + `radius`) quando aplicável.
- Paginação por cursor.
- Retornar apenas linhas ativas.
- Ordenação previsível: correspondência exata, prefixo, depois nome.

**Critérios de aceite:**

- Busca por `3`, `0001` e trecho do nome funciona.
- Busca vazia retorna erro de validação.
- Nenhuma linha de outra cidade aparece.
- p95 < 300 ms para consultas comuns.

---

### RF-006 — Detalhes da linha

**Descrição:** retornar dados completos da linha, paradas e itinerário.

**Regras:**

- Aceitar UUID canônico, `codigoLinha` ou `sgLinha`.
- Resolver aliases sem ambiguidade; se ambíguo, retornar `409 ambiguous_line_code`.
- Retornar origem, destino, código de embarque, cidade e status.
- Retornar paradas na ordem do itinerário.
- Retornar `LineString` do traçado quando disponível.
- Se não houver traçado, retornar `route: null` sem erro.
- Respeitar overrides administrativos (RF-021).

**Critérios de aceite:**

- Detalhes por qualquer identificador válido retornam a mesma linha.
- Paradas mantêm a ordem.
- Linha sem traçado retorna `200` com `route: null`.
- Linha inexistente ou de outra cidade retorna `404`.

---

### RF-007 — Paradas

**Descrição:** consultar paradas por bounding box, busca e detalhes.

**Regras:**

- `GET /v1/cities/{citySlug}/stops?bbox=minLon,minLat,maxLon,maxLat` usa PostGIS.
- Limitar área máxima para evitar consultas abusivas.
- Busca por código, nome e endereço.
- Detalhes incluem linhas que passam na parada.
- Ordenar por distância quando houver ponto de referência.

**Critérios de aceite:**

- Bounding box retorna apenas paradas dentro da área e da cidade.
- Busca por código e nome funciona.
- p95 < 300 ms para áreas urbanas típicas.

---

### RF-008 — Itinerário geográfico

**Descrição:** retornar o traçado da linha para o mapa.

**Regras:**

- Armazenar `LineString` em `geography(LineString,4326)`.
- Suportar sentido ida/volta quando disponível.
- Retornar coordenadas em ordem.
- Cachear com ETag/versão.
- Incluir `updatedAt` da importação de origem.

**Critérios de aceite:**

- App desenha o traçado no mapa.
- Linha sem traçado não quebra a tela.
- Resposta inclui versão/atualização.

---

### RF-009 — Posições atuais

**Descrição:** retornar as posições mais recentes dos veículos de uma linha.

**Regras:**

- Exigir `accessLevel` `trial` ou `paid`; caso contrário `402 subscription_required`.
- Retornar no máximo uma posição por veículo.
- Considerar a captura mais recente dentro da janela configurada.
- Incluir `capturedAt`, `generatedAt`, `receivedAt`, `source`, `dataMode` e `isStale`.
- `isStale = true` quando a captura exceder 2 minutos.
- Não inventar posições nem interpolar.
- Cache curto (5–15 s) por linha.
- Se não houver posição recente, retornar lista vazia com `sourceStatus`.
- Polling no MVP; sem WebSocket.

**Critérios de aceite:**

- Posição exibida no mapa com horário de captura.
- Posição antiga marcada como `stale`.
- Nenhuma posição duplicada por veículo.
- `read_only` e `catalog_only` recebem `402`.
- p95 < 500 ms com cache.

---

### RF-010 — Sessões de rastreamento, heartbeat e cotas

**Descrição:** registrar o acompanhamento de linhas, manter a sessão viva e aplicar limites.

**Regras de criação**

- `POST /v1/cities/{citySlug}/tracking-sessions` com `lineId` e `Idempotency-Key`.
- Exige `trial` ou `paid`; caso contrário `402 subscription_required`.
- **Trial:** no máximo **1 sessão ativa**. Nova tentativa retorna `409 active_session_exists` com o `sessionId` atual.
- **Pago:** várias sessões ativas permitidas.
- Encerrar e iniciar novamente **conta como novo rastreamento**.
- Favoritar, desfavoritar e abrir favorito não consomem cota.
- Fim do rastreamento não devolve cota.

**Contagem (D29)**

- 1 rastreamento = **1 linha acompanhada**.
- Duas linhas simultâneas (plano pago) = 2 rastreamentos.
- Trocar de linha no trial encerra a atual e consome 1 novo rastreamento.
- Limite do trial: 5 rastreamentos por dia.
- Pago: sem limite diário, mas o uso é registrado para métricas.

**Exceções que não contam** (proteção contra falha de rede)

1. Retry com a mesma `Idempotency-Key`.
2. Reabertura de sessão ainda viva (heartbeat dentro do TTL).
3. App em background/morto e reaberto dentro do TTL.

**Heartbeat (D28)**

- App envia `POST /v1/tracking-sessions/{id}/heartbeat` a cada 30 s.
- Backend renova `expires_at = now + TTL` (default 120 s, configurável).
- Encerramento explícito: `POST /v1/tracking-sessions/{id}/end`.
- Job periódico encerra sessões vencidas e libera o slot do trial.
- `ended_reason`: `user_stopped`, `line_changed`, `heartbeat_timeout`, `trial_expired`, `subscription_expired`, `account_deleted`.

**Cota e fuso (D30)**

- Cota é **global por conta**, independente da cidade.
- O "dia" é calculado no fuso da **cidade selecionada no momento da criação da sessão** (`catalog_city.timezone`).
- Teresina: `America/Fortaleza`.
- Gravar `quota_day` e `quota_timezone` na sessão e em `tracking_usage_daily`, para a contagem não mudar retroativamente.
- Reset à meia-noite do fuso da cidade.

**Concorrência**

- Validar em transação com `select_for_update`.
- Retornar `trackingRemainingToday` atualizado.
- Sessões expiradas por timeout não bloqueiam novo rastreamento.

**Critérios de aceite:**

- 5 inícios no trial funcionam; o 6º retorna `429 tracking_quota_exceeded`.
- Segunda sessão simultânea no trial retorna `409 active_session_exists`.
- Duas requisições concorrentes não ultrapassam o limite.
- Retry com a mesma chave não conta duas vezes.
- Sessão sem heartbeat expira em até TTL + 30 s.
- Pago não é bloqueado.
- Reset ocorre no fuso da cidade, não em UTC nem em horário do servidor.
- Fim do trial encerra sessões ativas com `trial_expired`.

---

### RF-011 — Favoritos

**Descrição:** permitir favoritar linhas e consultar favoritos.

**Regras:**

- **Antes do trial (`catalog_only`): bloqueado.** `POST`/`DELETE` retornam `402 subscription_required`; o app mostra o paywall.
- **Trial:** no máximo 1 favorito.
- **Pago:** ilimitado.
- **`read_only`:** leitura permitida; escrita bloqueada com `402`.
- Favoritar/desfavoritar/abrir não consome cota.
- Adicionar favorito é idempotente.
- Limite validado em transação.
- `favorite_limit_reached` (409) quando aplicável.
- Retornar `city` em cada favorito para o app montar a UI sem consultas extras.
- Favoritos são globais por usuário, filtráveis por cidade no app.

**Critérios de aceite:**

- `catalog_only` não consegue favoritar.
- Primeiro favorito funciona no trial.
- Segundo favorito no trial retorna erro estável com oferta de assinatura.
- Remover e favoritar outra linha funciona sem consumir cota.
- Duas requisições concorrentes não criam dois favoritos no trial.
- `read_only` lista favoritos antigos, mas não altera.

---

### RF-012 — Trial, assinatura e entitlements

**Descrição:** controlar trial de 7 dias e assinatura mensal.

**Regras:**

- **Trial via loja (D21):** oferta introdutória de 7 dias na App Store/Google Play, **com cartão**, gerenciada pelo RevenueCat.
- **Oferecido no primeiro rastreamento (D19):** o paywall aparece quando o usuário tenta acompanhar uma linha ou favoritar. O trial só começa quando ele aceita a oferta na loja.
- **Sem trial pelo backend:** não existe `POST /v1/trial/start`, `billing_trial` nem `trial_consumed`.
- Elegibilidade ao trial é decidida pela loja/RevenueCat; o backend reflete o estado.
- **Assinatura mensal apenas** (`meubuzu_monthly`), sem plano anual e sem web.
- RevenueCat é a fonte de verdade para iOS/Android.
- Webhooks assinados e idempotentes atualizam `billing_subscription` e entitlements.
- Não confiar em compras informadas pelo app.
- Oferecer `managementUrl` e suporte a "Restaurar compras".
- Período de graça: 3 dias, configurável no RevenueCat (D26).
- Eventos tratados: `INITIAL_PURCHASE`, `RENEWAL`, `CANCELLATION`, `UNCANCELLATION`, `EXPIRATION`, `BILLING_ISSUE`, `PRODUCT_CHANGE`, `SUBSCRIPTION_PAUSED`, `TRANSFER`.
- Evento `TRANSFER` move o entitlement entre contas e é auditado.
- Reembolso/chargeback revoga o acesso quando a loja notificar.

**Mapeamento de estado**

| Situação na loja | `accessLevel` |
|---|---|
| Sem compra, nunca usou trial | `catalog_only` |
| Período introdutório ativo | `trial` |
| Assinatura ativa | `paid` |
| Falha de cobrança dentro da graça | `paid` (com aviso) |
| Expirado/cancelado ao fim do período | `read_only` |

**Critérios de aceite:**

- Trial expira na data informada pela loja.
- Webhook válido ativa assinatura.
- Webhook duplicado não duplica efeitos.
- Assinatura reembolsada revoga acesso conforme regra.
- App exibe status, data de término, `willRenew` e link de gerenciamento.
- Usuário inelegível vê paywall apenas com o mensal (ver D34).

---

### RF-013 — Administração

**Descrição:** operar cidades, catálogo, importações, usuários e assinaturas pelo Django Admin.

**Regras:**

- CRUD de cidades, linhas, paradas, itinerários, veículos, fontes e aliases.
- Visualização de importações, ingestões e erros.
- Busca e filtros.
- Permissões por grupo.
- 2FA obrigatório para administradores.
- Auditoria de alterações.
- Não expor tokens, códigos ou dados sensíveis.
- Acesso restrito por IP/VPN quando possível.
- Edição de dados importados segue a RF-021 (override auditado).
- Ações em massa exigem confirmação e geram auditoria.

**Critérios de aceite:**

- Operação consegue corrigir uma parada e ver o efeito na API.
- Toda alteração relevante gera registro de auditoria.
- Usuário sem permissão não acessa o admin.
- Admin não consegue disparar import de cidade sem fonte configurada.

---

### RF-014 — Ingestão de posições

**Descrição:** receber, validar, normalizar e armazenar posições.

**Regras:**

- Interface `PositionSource` com implementações:
  - `CsvDemoSource` (staging)
  - `TeresinaApiSource` (produção)
  - `GtfsRealtimeSource`
  - `HttpJsonSource`
  - `WebhookSource`
- Pipeline: buscar → validar → normalizar → deduplicar → inserir → atualizar última posição → registrar saúde.
- Chave de deduplicação: veículo + captura + fonte.
- Inserção em lote.
- Lock distribuído para evitar execuções sobrepostas.
- Retry com backoff e circuit breaker.
- Alertar quando a fonte ficar sem atualizar.
- Guardar payload bruto por janela curta para auditoria/replay.
- Tabela de quarentena para dados inválidos.
- **Nunca preencher lacunas com posição inventada ou interpolada.**

**Critérios de aceite:**

- Replay dos CSVs popula posições e o app as exibe em staging.
- Dados duplicados não geram duplicatas.
- Dados inválidos são rejeitados e registrados.
- Falha da fonte gera alerta e não derruba a API.
- Ingestão suporta a carga simulada definida nos testes.
- Produção recusa `CsvDemoSource`.

---

### RF-015 — Frescura e status dos dados

**Descrição:** informar ao app a idade e a origem dos dados.

**Regras:**

- Toda resposta de posição inclui timestamps, `source`, `dataMode` e `isStale`.
- `isStale` calculado no servidor (limite de 2 minutos).
- Não retornar posição sem `capturedAt`.
- Expor status da fonte apenas para admin/operação.
- O app deve exibir "atualizado há X" e aviso de dados antigos.
- Staging exibe banner "Dados de demonstração" sempre que `dataMode=demo`.

**Critérios de aceite:**

- Posição recente retorna `isStale=false`.
- Posição antiga retorna `isStale=true`.
- App não apresenta dado antigo como atual.
- Origem demo nunca aparece sem aviso visual.

---

### RF-016 — Saúde e métricas

**Descrição:** expor endpoints operacionais.

**Regras:**

- `GET /healthz`: processo vivo.
- `GET /readyz`: banco, Redis e dependências críticas.
- `GET /metrics`: métricas internas (Prometheus), sem exposição pública.
- Logs estruturados com request ID.
- Sentry para erros.

**Critérios de aceite:**

- Orquestrador consegue reiniciar instâncias com base nos health checks.
- Métricas permitem identificar latência, erros, atraso de ingestão e falha de import.

---

### RF-017 — Contrato e erros

**Descrição:** padronizar a API.

**Regras:**

- OpenAPI gerado e versionado.
- Erros no formato Problem Details (RFC 9457).
- Códigos de erro estáveis.
- Paginação por cursor.
- `Idempotency-Key` em criação, rastreamento e webhooks.
- Timestamps ISO 8601 em UTC.
- Versionamento `/v1`.
- Cidade sempre explícita nas rotas de catálogo e rastreamento.

**Critérios de aceite:**

- Client Dart compila contra o OpenAPI.
- CI detecta breaking changes.
- App trata erros por código, não por texto.
- Nenhuma rota de catálogo funciona sem cidade.

---

### RF-018 — Privacidade, LGPD e exclusão de conta

**Descrição:** atender direitos do titular e minimizar dados.

**Regras:**

- Coletar apenas e-mail e dados necessários.
- Não enviar localização do usuário ao backend.
- Exclusão de conta disponível no app, com confirmação explícita.
- **Exclusão total dos dados do usuário (D31):** conta, preferência, favoritos, sessões de rastreamento, refresh tokens, códigos de e-mail e eventos de uso.
- Preservar apenas o mínimo exigido por obrigação legal/fiscal, minimizado e com prazo definido.
- Avisar que a assinatura da loja **não** é cancelada automaticamente; oferecer link de gerenciamento.
- Elegibilidade do trial permanece na conta da loja; exclusão no backend não gera novo trial.
- Permitir exportação dos dados antes da exclusão.
- Não registrar PII em logs.
- Documentar base legal, retenção e política de privacidade.
- Consentimento e transparência no app.

**Critérios de aceite:**

- Solicitação de exclusão remove os dados e encerra sessões ativas.
- Sessões de rastreamento ativas são encerradas com `account_deleted`.
- Assinatura ativa continua válida na loja e é informada ao usuário.
- Logs não contêm e-mail completo, OTP ou tokens.
- Retenção é aplicada por job.
- Exportação entrega os dados do usuário em formato legível.

---

### RF-019 — Cidades e preferência de cidade

**Descrição:** listar cidades suportadas e sincronizar a cidade escolhida entre dispositivos.

**Regras:**

- `GET /v1/cities` lista apenas cidades ativas, com `slug`, `name`, `state`, `timezone`, `isActive` e cobertura.
- `GET /v1/me/preferences` retorna `selectedCity`, `updatedAt` e `version`.
- `PUT /v1/me/preferences` com `{ "selectedCitySlug": "teresina" }`, idempotente.
- Validar cidade existente e ativa: `404 city_not_found` e `409 city_inactive`.
- Um usuário tem no máximo uma preferência.
- `selectedCity` começa nulo.
- Concorrência: *last write wins* com `updatedAt` do servidor; `version` opcional via `If-Match`.
- `preferences` também é retornado em `POST /v1/auth/verify-code`.
- O backend usa a preferência como default, mas **não** infere cidade em requisições de catálogo.
- Troca de cidade encerra sessões ativas com `line_changed` e limpa caches do app.
- Se a cidade salva ficar inativa, o app reabre o seletor.

**Critérios de aceite:**

- Usuário novo sem preferência vê o seletor de cidades.
- Ao escolher Teresina, a preferência é salva no backend.
- Ao logar em outro dispositivo, Teresina é restaurada automaticamente.
- Trocar para cidade inativa retorna erro estável e o app reabre o seletor.
- Se o `PUT` falhar, a seleção local é preservada e sincronizada depois.
- Nenhuma requisição de catálogo ocorre sem cidade explícita.
- Seletor aparece mesmo com apenas Teresina ativa (D32).

---

### RF-020 — Importação de catálogo

**Descrição:** importar linhas, paradas, itinerários e trajetos da API da cidade em ciclos periódicos.

**Regras:**

- Frequência configurável por cidade: `weekly` (default) ou `monthly`.
- Execução agendada por Celery beat e execução manual pelo admin ("Importar agora").
- Pré-visualização do diff antes de aplicar: adicionadas, alteradas, removidas, erros.
- Idempotente: reimportar o mesmo payload não duplica nada.
- **Nunca apaga registros**: itens ausentes na origem viram `is_active=false` e geram alerta.
- Relatório por execução (`catalog_import_run`): início, fim, contagens, erros, origem, status.
- Falha parcial não aborta tudo: aplica o válido e registra o restante.
- Reconstruir índices de busca (`pg_trgm`) ao final.
- Aliases e metadados locais **nunca** são sobrescritos pelo import.
- Toda execução gera auditoria e métrica.
- Produção usa `TeresinaApiSource`; staging usa `CsvDemoSource`.

**Critérios de aceite:**

- Import repetido não altera contagens.
- Item removido na origem fica inativo, não apagado.
- Aliases locais sobrevivem ao import.
- Relatório mostra contagens e erros por execução.
- Falha total não deixa o catálogo em estado inconsistente.
- Import manual fica registrado com o usuário que disparou.

---

### RF-021 — Edição administrativa e governança de dados

**Descrição:** permitir que o admin edite qualquer dado importado, sem perder o trabalho no próximo import.

**Regras:**

- O import é a fonte de verdade padrão.
- O admin pode editar qualquer campo de qualquer registro.
- Campo editado manualmente é **fixado** (`catalog_admin_override`), com autor, data e valor.
- O read path aplica o override sobre o valor importado.
- O admin mostra a origem de cada campo: `API` ou `manual`.
- Ação "voltar para a API" remove o override e volta a acompanhar a importação.
- Registros que somem da API e estejam fixados **não** são desativados; geram alerta para revisão.
- O admin pode criar registros inexistentes na API (`origin=manual`), que nunca são alterados pelo import.
- Toda edição, fixação e remoção de override vai para `common_audit_log`.

**Critérios de aceite:**

- Edição sem fixação é substituída no próximo import e o admin é avisado disso na tela.
- Edição fixada sobrevive ao import.
- "Voltar para a API" restaura o valor importado.
- Registro manual não é desativado pelo import.
- Auditoria identifica autor, data, antes e depois.

---

### RF-022 — Modo demonstração (staging)

**Descrição:** permitir demonstração completa do produto sem dados reais.

**Regras:**

- Staging usa `CsvDemoSource`, com timestamps deslocados para "agora".
- Toda resposta inclui `dataMode: "demo"` e `source: "csv_demo"`.
- App de staging exibe banner permanente "Dados de demonstração".
- Sem cobrança, sem anúncios, sem paywall: todos os limites liberados para testadores.
- Contas de teste, sem PII real.
- Produção rejeita `demo` na inicialização.
- Reset periódico do banco de staging.

**Critérios de aceite:**

- Nenhuma resposta de staging sai sem `dataMode=demo`.
- Banner visível em todas as telas de mapa.
- Replay mantém a demonstração "viva" sem parecer dado real.
- Produção falha ao iniciar com `DATA_MODE=demo`.

---

## 9. Requisitos não funcionais

### 9.1 Segurança

- OWASP ASVS nível 1/2 como referência.
- TLS obrigatório; HSTS em produção.
- CORS restrito ao necessário para desenvolvimento; app mobile não depende de CORS.
- Headers de segurança.
- Validação de entrada em todos os endpoints.
- ORM/consultas parametrizadas.
- Usuário de banco com privilégio mínimo.
- Secrets em secret manager; nunca no repositório.
- Rate limiting por IP, usuário e dispositivo.
- Proteção contra brute force em OTP.
- Refresh token com rotação e detecção de reuso.
- Webhooks com verificação de assinatura.
- Dependências auditadas no CI.
- Admin com 2FA e acesso restrito.
- Nenhum dado de demonstração em produção.

### 9.2 Performance

| Métrica | Meta MVP |
|---|---|
| Busca de linhas/paradas p95 | < 300 ms |
| Detalhes de linha p95 | < 300 ms |
| Posições p95 (com cache) | < 500 ms |
| Criação de sessão p95 | < 400 ms |
| Heartbeat p95 | < 150 ms |
| Ingestão | suportar 10x a frota inicial |
| Disponibilidade MVP | 99,5% |
| Disponibilidade alvo | 99,9% |

### 9.3 Confiabilidade

- Backup gerenciado com point-in-time recovery (7–14 dias).
- Teste de restauração trimestral.
- RPO alvo: 5–15 minutos.
- RTO alvo: 4 horas.
- Migrations compatíveis com deploy sem downtime.
- Staging separado.
- Circuit breaker na ingestão.
- Degradação graciosa: catálogo continua funcionando se a fonte de posições cair.
- Falha de import não desativa catálogo existente.
- Sessões órfãs são encerradas por job.

### 9.4 Escalabilidade

- API stateless, escalável horizontalmente.
- Postgres com índices adequados e partições de posições.
- Cache Redis para posições e consultas quentes.
- Read replicas quando necessário.
- Projetar para 10x a frota inicial sem mudança de arquitetura.

### 9.5 Observabilidade

- Sentry para exceções.
- Logs estruturados JSON com request ID.
- Métricas: latência, taxa de erro, filas, atraso de ingestão, import, OTP enviado/validado, sessões ativas e expiradas.
- Dashboards e alertas.
- Uptime monitor externo.

### 9.6 Privacidade e LGPD

- Minimização de dados.
- Retenção definida por tipo.
- Exclusão total sob solicitação, com exceções legais mínimas.
- Sem PII em logs.
- Localização do usuário processada no dispositivo.
- Política de privacidade e termos publicados antes do lançamento.
- Registro de tratamento e encarregado (DPO) quando aplicável.

### 9.7 Manutenibilidade

- Testes automatizados.
- CI com lint, tipos, testes, segurança e build.
- Documentação e ADRs.
- Textos de produto em português; identificadores em inglês, seguindo o padrão do projeto.

### 9.8 Custo

- Custo inicial alvo: até US$ 70/mês.
- Alertas de orçamento.
- Free tiers quando possível.
- RevenueCat gratuito até o limite de receita.

## 10. Modelo de dados

### 10.1 Extensões

- `postgis`
- `citext`
- `pg_trgm`

### 10.2 Contas e acesso

#### `accounts_user`

| Campo | Tipo | Restrições |
|---|---|---|
| id | UUID | PK |
| email | CITEXT | único, obrigatório |
| email_verified_at | timestamptz | nullable |
| is_active | boolean | default true |
| deleted_at | timestamptz | nullable |
| created_at | timestamptz | auto |
| updated_at | timestamptz | auto |

> Usar User customizado desde a primeira migration.

#### `accounts_email_code`

| Campo | Tipo | Restrições |
|---|---|---|
| id | UUID | PK |
| email | CITEXT | indexado |
| code_hash | text | obrigatório |
| expires_at | timestamptz | obrigatório |
| consumed_at | timestamptz | nullable |
| attempts | int | default 0 |
| ip | inet | nullable |
| user_agent | text | nullable |
| created_at | timestamptz | auto |

Índice: `(email, created_at desc)`.

#### `accounts_refresh_session`

| Campo | Tipo | Restrições |
|---|---|---|
| id | UUID | PK |
| user_id | FK | indexado |
| token_hash | text | único |
| device_id | text | nullable |
| expires_at | timestamptz | obrigatório |
| revoked_at | timestamptz | nullable |
| replaced_by_id | FK self | nullable |
| last_used_at | timestamptz | nullable |
| created_at | timestamptz | auto |

#### `accounts_user_preference`

| Campo | Tipo | Restrições |
|---|---|---|
| user_id | UUID | PK, FK para usuário, `ON DELETE CASCADE` |
| selected_city_id | UUID | FK para `catalog_city`, nullable |
| version | integer | default 0 |
| updated_at | timestamptz | auto |

- Uma preferência por usuário.
- `selected_city_id` começa nulo.
- Índice em `selected_city_id` para métricas de adoção por cidade.
- Sem histórico de cidades; auditoria em `common_audit_log` quando necessário.

#### `accounts_deletion_request`

| Campo | Tipo | Restrições |
|---|---|---|
| id | UUID | PK |
| user_id | UUID | indexado |
| requested_at | timestamptz | auto |
| completed_at | timestamptz | nullable |
| status | text | `pending`, `completed`, `failed` |
| reason | text | nullable |
| retained_data | jsonb | mínimo legal, com prazo |

### 10.3 Catálogo

#### `catalog_city`

| Campo | Tipo | Restrições |
|---|---|---|
| id | UUID | PK |
| slug | text | único (`teresina`) |
| name | text | `Teresina` |
| state | char(2) | `PI` |
| country | char(2) | `BR` |
| timezone | text | `America/Fortaleza` |
| center | geography(Point,4326) | centro do mapa inicial |
| import_interval | text | `weekly`, `monthly` |
| is_active | boolean | default true |
| coverage_note | text | nullable |
| created_at | timestamptz | auto |
| updated_at | timestamptz | auto |

- `timezone` define o dia da cota (D30). Nunca hardcoded no código.
- `import_interval` define a cadência do import de catálogo.

#### `catalog_source`

| Campo | Tipo | Restrições |
|---|---|---|
| id | UUID | PK |
| city_id | FK | indexado |
| name | text | |
| kind | text | `teresina_api`, `csv_demo`, `gtfs`, `http_json` |
| base_url | text | nullable |
| config | jsonb | sem segredos em texto |
| is_active | boolean | |
| last_import_at | timestamptz | nullable |
| last_error_at | timestamptz | nullable |

#### `catalog_import_run`

| Campo | Tipo | Restrições |
|---|---|---|
| id | UUID | PK |
| city_id | FK | indexado |
| source_id | FK | indexado |
| trigger | text | `schedule`, `manual` |
| triggered_by_id | FK | nullable |
| started_at | timestamptz | |
| finished_at | timestamptz | nullable |
| status | text | `success`, `partial`, `failed` |
| counters | jsonb | adicionadas, alteradas, removidas, erros |
| errors | jsonb | amostra de erros |
| data_mode | text | `demo`, `live` |

#### `catalog_admin_override`

| Campo | Tipo | Restrições |
|---|---|---|
| id | UUID | PK |
| city_id | FK | indexado |
| entity | text | `line`, `stop`, `route`, `line_stop`, `vehicle` |
| entity_id | UUID | indexado |
| field | text | nome do campo |
| value | jsonb | valor fixado |
| created_by_id | FK | admin |
| created_at | timestamptz | auto |
| updated_at | timestamptz | auto |

Restrição: único `(entity, entity_id, field)`.

#### `catalog_line`

| Campo | Tipo | Restrições |
|---|---|---|
| id | UUID | PK |
| city_id | FK | indexado |
| source_id | FK | indexado |
| external_id | text | id na origem |
| code | text | `codigoLinha`; único por cidade |
| boarding_code | text | `sgLinha`; indexado |
| name | text | obrigatório |
| origin | text | |
| destination | text | |
| origin_type | text | `imported`, `manual` |
| is_active | boolean | default true |
| source_updated_at | timestamptz | nullable |
| created_at | timestamptz | auto |
| updated_at | timestamptz | auto |

Índice de busca: `pg_trgm` em `name`, `code` e `boarding_code`.

#### `catalog_line_alias`

| Campo | Tipo | Restrições |
|---|---|---|
| id | UUID | PK |
| line_id | FK | indexado |
| alias | text | único por linha |
| kind | text | `codigo`, `sglinha`, `legacy`, `local` |

> Aliases são **locais** e nunca são apagados por import.

#### `catalog_stop`

| Campo | Tipo | Restrições |
|---|---|---|
| id | UUID | PK |
| city_id | FK | indexado |
| source_id | FK | indexado |
| external_id | text | id original |
| code | text | único por cidade |
| name | text | obrigatório |
| address | text | |
| location | geography(Point,4326) | obrigatório, índice GiST |
| accessibility | jsonb | nullable |
| origin_type | text | `imported`, `manual` |
| is_active | boolean | default true |
| created_at | timestamptz | auto |
| updated_at | timestamptz | auto |

#### `catalog_line_stop`

| Campo | Tipo | Restrições |
|---|---|---|
| id | UUID | PK |
| line_id | FK | indexado |
| stop_id | FK | indexado |
| direction | smallint | 0/1 |
| sequence | int | |
| created_at | timestamptz | auto |

Restrições: único `(line_id, direction, sequence)` e `(line_id, stop_id, direction)`.

#### `catalog_route`

| Campo | Tipo | Restrições |
|---|---|---|
| id | UUID | PK |
| line_id | FK | indexado |
| direction | smallint | |
| path | geography(LineString,4326) | obrigatório |
| updated_at | timestamptz | auto |

Restrição: único `(line_id, direction)`.

#### `catalog_vehicle`

| Campo | Tipo | Restrições |
|---|---|---|
| id | UUID | PK |
| city_id | FK | indexado |
| source_id | FK | indexado |
| code | text | único por cidade |
| label | text | |
| accessibility | jsonb | nullable |
| created_at | timestamptz | auto |
| updated_at | timestamptz | auto |

#### `catalog_vehicle_line_assignment`

| Campo | Tipo | Restrições |
|---|---|---|
| id | UUID | PK |
| vehicle_id | FK | indexado |
| line_id | FK | indexado |
| valid_from | timestamptz | |
| valid_to | timestamptz | nullable |

Restrição: exclusão por sobreposição com `tstzrange` e `EXCLUDE USING gist`.

### 10.4 Rastreamento

#### `tracking_position`

| Campo | Tipo | Restrições |
|---|---|---|
| id | bigint | PK |
| city_id | FK | indexado |
| vehicle_id | FK | indexado |
| line_id | FK | indexado |
| location | geography(Point,4326) | obrigatório, GiST |
| captured_at | timestamptz | obrigatório, BRIN |
| generated_at | timestamptz | nullable |
| speed | numeric | nullable |
| heading | numeric | nullable |
| source_id | FK | indexado |
| data_mode | text | `demo`, `live` |
| ingested_at | timestamptz | auto |

- Particionada por range de `captured_at` (mensal).
- Único `(vehicle_id, captured_at, source_id)`.
- Checks de latitude/longitude, velocidade e direção.
- **Retenção: 30 dias** (D15), com job de expurgo diário.

#### `tracking_latest_position`

| Campo | Tipo | Restrições |
|---|---|---|
| vehicle_id | UUID | PK |
| city_id | FK | indexado |
| line_id | FK | indexado |
| location | geography(Point,4326) | obrigatório |
| captured_at | timestamptz | obrigatório |
| generated_at | timestamptz | nullable |
| source_id | FK | |
| data_mode | text | `demo`, `live` |
| updated_at | timestamptz | auto |

Atualizada por upsert na mesma transação da ingestão.

#### `tracking_session`

| Campo | Tipo | Restrições |
|---|---|---|
| id | UUID | PK |
| user_id | FK | indexado |
| city_id | FK | indexado |
| line_id | FK | indexado |
| started_at | timestamptz | |
| last_heartbeat_at | timestamptz | |
| expires_at | timestamptz | indexado |
| ended_at | timestamptz | nullable |
| ended_reason | text | `user_stopped`, `line_changed`, `heartbeat_timeout`, `trial_expired`, `subscription_expired`, `account_deleted` |
| counted | boolean | default true |
| quota_day | date | |
| quota_timezone | text | `America/Fortaleza` |
| idempotency_key | text | único por usuário |
| data_mode | text | `demo`, `live` |

Índices parciais: sessão aberta por usuário; `expires_at` para o job de expiração.

#### `tracking_usage_daily`

| Campo | Tipo | Restrições |
|---|---|---|
| id | bigint | PK |
| user_id | FK | indexado |
| quota_day | date | |
| quota_timezone | text | |
| tracking_count | int | default 0 |

Único `(user_id, quota_day)`.

#### `tracking_source`

| Campo | Tipo | Restrições |
|---|---|---|
| id | UUID | PK |
| city_id | FK | indexado |
| name | text | |
| kind | text | `teresina_api`, `csv_demo`, `gtfs_rt`, `http_json`, `webhook` |
| config | jsonb | sem segredos em texto |
| is_active | boolean | |
| last_success_at | timestamptz | nullable |
| last_error_at | timestamptz | nullable |
| last_error_message | text | nullable |

#### `tracking_ingestion_run`

| Campo | Tipo | Restrições |
|---|---|---|
| id | UUID | PK |
| source_id | FK | indexado |
| started_at | timestamptz | |
| finished_at | timestamptz | nullable |
| status | text | `success`, `partial`, `failed` |
| counters | jsonb | |
| error_message | text | nullable |

### 10.5 Monetização

#### `favorites_favorite`

| Campo | Tipo | Restrições |
|---|---|---|
| id | UUID | PK |
| user_id | FK | indexado |
| line_id | FK | indexado |
| created_at | timestamptz | auto |

Único `(user_id, line_id)`.

#### `billing_subscription`

| Campo | Tipo | Restrições |
|---|---|---|
| id | UUID | PK |
| user_id | FK | indexado |
| provider | text | `revenuecat` |
| store | text | `app_store`, `play_store` |
| product_id | text | `meubuzu_monthly` |
| status | text | `trial`, `active`, `grace`, `expired`, `canceled` |
| period_type | text | `trial`, `normal` |
| current_period_start | timestamptz | |
| current_period_end | timestamptz | |
| will_renew | boolean | |
| original_transaction_id | text | |
| management_url | text | |
| environment | text | `sandbox`, `production` |
| updated_at | timestamptz | auto |

Único `(provider, original_transaction_id)`.

> Não existe `billing_trial`: o trial é um período introdutório da loja, representado por `status=trial` e `period_type=trial`.

#### `billing_webhook_event`

| Campo | Tipo | Restrições |
|---|---|---|
| id | UUID | PK |
| provider | text | `revenuecat` |
| event_id | text | único por provedor |
| event_type | text | |
| payload | jsonb | |
| status | text | `pending`, `processed`, `failed` |
| processed_at | timestamptz | nullable |
| error_message | text | nullable |

### 10.6 Operação

#### `common_audit_log`

| Campo | Tipo | Restrições |
|---|---|---|
| id | bigint | PK |
| actor_id | FK | nullable |
| actor_type | text | `user`, `admin`, `system` |
| action | text | |
| entity | text | |
| entity_id | text | |
| before | jsonb | nullable |
| after | jsonb | nullable |
| ip | inet | nullable |
| created_at | timestamptz | auto |

### 10.7 Invariantes

1. Toda linha, parada e veículo pertence a uma cidade.
2. Toda requisição de catálogo tem cidade explícita no path.
3. Um usuário tem no máximo uma preferência de cidade.
4. No trial existe no máximo **uma sessão aberta** por usuário.
5. Uma sessão aberta sempre tem `expires_at`.
6. `tracking_usage_daily` é único por `(user_id, quota_day)`.
7. Override é único por `(entity, entity_id, field)`.
8. Item importado ausente na origem fica inativo, nunca é apagado.
9. Alias local nunca é apagado por import.
10. Produção não contém registro com `data_mode = demo`.

---

## 11. API

### 11.1 Convenções

- Base: `/v1`.
- Auth: `Authorization: Bearer <access_token>`.
- Conteúdo: `application/json`.
- Timestamps: ISO 8601 UTC.
- Erros: RFC 9457 (`application/problem+json`).
- Paginação: cursor (`next_cursor`, `has_more`).
- Idempotência: header `Idempotency-Key`.
- Rate limit: headers `X-RateLimit-*` e `Retry-After`.
- Cidade explícita em todas as rotas de catálogo e rastreamento.

### 11.2 Endpoints

#### Autenticação e conta

| Método | Rota | Auth | Descrição |
|---|---|---|---|
| POST | `/v1/auth/request-code` | Pública | Solicita código OTP |
| POST | `/v1/auth/verify-code` | Pública | Verifica código e autentica |
| POST | `/v1/auth/refresh` | Refresh | Renova tokens |
| POST | `/v1/auth/logout` | Access | Revoga sessão |
| GET | `/v1/me` | Access | Perfil |
| DELETE | `/v1/me` | Access | Exclui conta e dados |
| GET | `/v1/me/export` | Access | Exporta dados do titular |
| GET | `/v1/me/preferences` | Access | Cidade selecionada |
| PUT | `/v1/me/preferences` | Access | Atualiza cidade selecionada |
| GET | `/v1/me/entitlements` | Access | Nível de acesso e limites |

#### Cidades

| Método | Rota | Auth | Descrição |
|---|---|---|---|
| GET | `/v1/cities` | Access | Cidades ativas |
| GET | `/v1/cities/{citySlug}` | Access | Detalhes da cidade |

#### Catálogo

| Método | Rota | Auth | Descrição |
|---|---|---|---|
| GET | `/v1/cities/{citySlug}/lines` | Access | Busca linhas |
| GET | `/v1/cities/{citySlug}/lines/{id}` | Access | Detalhes da linha |
| GET | `/v1/cities/{citySlug}/lines/{id}/stops` | Access | Paradas da linha |
| GET | `/v1/cities/{citySlug}/lines/{id}/route` | Access | Traçado |
| GET | `/v1/cities/{citySlug}/lines/{id}/positions` | Trial/Pago | Posições atuais |
| GET | `/v1/cities/{citySlug}/stops` | Access | Busca/bbox de paradas |
| GET | `/v1/cities/{citySlug}/stops/{id}` | Access | Detalhes da parada |
| GET | `/v1/cities/{citySlug}/stops/{id}/lines` | Access | Linhas da parada |

#### Rastreamento e favoritos

| Método | Rota | Auth | Descrição |
|---|---|---|---|
| POST | `/v1/cities/{citySlug}/tracking-sessions` | Trial/Pago | Inicia rastreamento |
| POST | `/v1/tracking-sessions/{id}/heartbeat` | Trial/Pago | Mantém sessão viva |
| POST | `/v1/tracking-sessions/{id}/end` | Trial/Pago | Encerra rastreamento |
| GET | `/v1/tracking-sessions/active` | Trial/Pago | Sessões abertas |
| GET | `/v1/favorites` | Access | Lista favoritos |
| POST | `/v1/favorites` | Trial/Pago | Adiciona favorito |
| DELETE | `/v1/favorites/{lineId}` | Trial/Pago | Remove favorito |

#### Webhooks, ingestão e operação

| Método | Rota | Auth | Descrição |
|---|---|---|---|
| POST | `/v1/webhooks/revenuecat` | Assinatura | Eventos de billing |
| POST | `/v1/ingest/positions` | HMAC/mTLS | Ingestão interna em lote |
| GET | `/healthz` | Pública | Liveness |
| GET | `/readyz` | Pública | Readiness |
| GET | `/metrics` | Interna | Métricas |

> `POST /v1/webhooks/stripe` foi removido: não há pagamento web (D22).

### 11.3 Exemplos

**Verificar código (com preferência e entitlements)**

```json
{
  "accessToken": "...",
  "refreshToken": "...",
  "user": { "id": "...", "email": "usuario@exemplo.com" },
  "preferences": {
    "selectedCity": { "slug": "teresina", "name": "Teresina", "state": "PI" },
    "version": 3,
    "updatedAt": "2026-11-16T18:00:00Z"
  },
  "entitlements": {
    "accessLevel": "catalog_only",
    "isPaid": false,
    "isTrial": false,
    "trialEndsAt": null,
    "maxActiveLines": 0,
    "maxFavorites": 0,
    "dailyTrackingLimit": 0,
    "trackingUsedToday": 0,
    "trackingRemainingToday": 0,
    "canTrack": false,
    "canViewPositions": false,
    "canManageFavorites": false,
    "quotaDate": "2026-11-16",
    "quotaTimezone": "America/Fortaleza"
  }
}
```

**Selecionar cidade**

```http
PUT /v1/me/preferences
Content-Type: application/json

{ "selectedCitySlug": "teresina" }
```

```json
{
  "selectedCity": { "slug": "teresina", "name": "Teresina", "state": "PI", "timezone": "America/Fortaleza" },
  "version": 1,
  "updatedAt": "2026-11-16T18:05:00Z"
}
```

**Iniciar rastreamento**

```http
POST /v1/cities/teresina/tracking-sessions
Idempotency-Key: 7c1f3a9e-...
Content-Type: application/json

{ "lineId": "..." }
```

```json
{
  "sessionId": "...",
  "lineId": "...",
  "startedAt": "2026-11-16T18:10:00Z",
  "lastHeartbeatAt": "2026-11-16T18:10:00Z",
  "expiresAt": "2026-11-16T18:12:00Z",
  "heartbeatIntervalSeconds": 30,
  "counted": true,
  "entitlements": {
    "accessLevel": "trial",
    "trackingUsedToday": 1,
    "trackingRemainingToday": 4,
    "maxActiveLines": 1
  }
}
```

**Posições**

```json
{
  "city": "teresina",
  "lineId": "...",
  "source": "teresina_api",
  "dataMode": "live",
  "isStale": false,
  "positions": [
    {
      "vehicleCode": "5093",
      "latitude": -5.070498,
      "longitude": -42.816973,
      "capturedAt": "2026-11-16T14:42:07Z",
      "generatedAt": "2026-11-16T14:41:52Z",
      "receivedAt": "2026-11-16T14:42:09Z",
      "speed": null,
      "heading": null
    }
  ]
}
```

**Erro de cota**

```http
429 Too Many Requests
Content-Type: application/problem+json

{
  "type": "https://api.meubuzu.com/problems/tracking-quota-exceeded",
  "title": "Limite diário de rastreamentos atingido",
  "status": 429,
  "code": "tracking_quota_exceeded",
  "detail": "O teste permite 5 rastreamentos por dia.",
  "retryAfter": "2026-11-17T03:00:00Z"
}
```

**Sessão já ativa no trial**

```http
409 Conflict
Content-Type: application/problem+json

{
  "type": "https://api.meubuzu.com/problems/active-session-exists",
  "title": "Já existe um rastreamento ativo",
  "status": 409,
  "code": "active_session_exists",
  "detail": "Encerre o rastreamento atual para acompanhar outra linha.",
  "sessionId": "...",
  "lineId": "..."
}
```

### 11.4 Códigos de erro

| Código | HTTP | Significado |
|---|---|---|
| `invalid_email` | 400 | E-mail inválido |
| `invalid_code` | 401 | Código inválido |
| `code_expired` | 401 | Código expirado |
| `code_already_used` | 401 | Código já utilizado |
| `too_many_attempts` | 429 | Tentativas excedidas |
| `rate_limited` | 429 | Rate limit |
| `invalid_refresh_token` | 401 | Refresh inválido |
| `refresh_reuse_detected` | 401 | Reuso de refresh |
| `city_not_found` | 404 | Cidade inexistente |
| `city_inactive` | 409 | Cidade desativada |
| `line_not_found` | 404 | Linha não encontrada |
| `ambiguous_line_code` | 409 | Código ambíguo |
| `stop_not_found` | 404 | Parada não encontrada |
| `favorite_limit_reached` | 409 | Limite de favoritos |
| `active_session_exists` | 409 | Já existe sessão ativa no trial |
| `session_not_found` | 404 | Sessão inexistente ou de outro usuário |
| `session_expired` | 410 | Sessão expirada por falta de heartbeat |
| `tracking_quota_exceeded` | 429 | Cota diária |
| `subscription_required` | 402 | Recurso exige trial ou assinatura |
| `trial_not_eligible` | 409 | Conta sem direito à oferta introdutória |
| `source_unavailable` | 503 | Fonte de dados indisponível |
| `demo_mode_forbidden` | 500 | Produção configurada com dados demo |

---

## 12. Ingestão de dados

### 12.1 Duas pipelines

| Pipeline | Entrada | Saída | Cadência | Adaptador de produção |
|---|---|---|---|---|
| Catálogo | API de cadastro da cidade | linhas, paradas, itinerários, trajetos | semanal/mensal | `TeresinaApiSource` |
| Posições | API de tempo real | posições por veículo | 30 s | `TeresinaApiSource` |
| Demonstração | CSVs de `app/assets` | mesmo formato, `dataMode=demo` | contínuo | `CsvDemoSource` |

### 12.2 Interfaces

```python
class PositionSource(Protocol):
    def fetch(self) -> Iterable[VehiclePositionDTO]: ...

class CatalogSource(Protocol):
    def fetch_lines(self) -> Iterable[LineDTO]: ...
    def fetch_stops(self) -> Iterable[StopDTO]: ...
    def fetch_line_stops(self) -> Iterable[LineStopDTO]: ...
    def fetch_routes(self) -> Iterable[RouteDTO]: ...
```

### 12.3 Adaptadores

| Adaptador | Uso |
|---|---|
| `TeresinaApiSource` | Produção: catálogo e posições da API de Teresina |
| `CsvDemoSource` | Staging: replay dos CSVs atuais, com timestamps deslocados |
| `GtfsRealtimeSource` | Feed GTFS-RT `VehiclePositions`, se disponível |
| `HttpJsonSource` | Outras APIs municipais em JSON |
| `WebhookSource` | Operadora envia posições ao backend |

### 12.4 Pipeline de posições

1. Buscar lote.
2. Validar coordenadas, timestamps, velocidade e direção.
3. Resolver linha/veículo por aliases.
4. Deduplicar por veículo + captura + fonte.
5. Inserir em lote em `tracking_position`.
6. Upsert em `tracking_latest_position`.
7. Registrar `tracking_ingestion_run`.
8. Atualizar saúde da fonte.
9. Emitir métricas e logs.
10. Guardar payload bruto por janela curta.

### 12.5 Pipeline de catálogo

1. Disparar por agenda (`import_interval`) ou manualmente.
2. Baixar catálogo completo da fonte.
3. Validar e normalizar (códigos, aliases, geometrias, timestamps).
4. Calcular diff contra o estado atual, considerando overrides fixados.
5. Aplicar em transação: adicionar, atualizar e **desativar** ausentes.
6. Preservar aliases e metadados locais.
7. Reconstruir índices de busca.
8. Registrar `catalog_import_run` com contagens e erros.
9. Emitir métricas, alertas e auditoria.

**Falha parcial:** aplica o que for válido, registra o restante e retorna `partial`. **Falha total:** nenhuma alteração é aplicada.

### 12.6 Operação

- Celery beat para import de catálogo e ingestão de posições.
- Lock distribuído no Redis por cidade e por fonte.
- Retry com backoff exponencial.
- Circuit breaker.
- Alerta se a fonte não atualizar por X minutos.
- Alerta se o import atrasar mais que 1,5× o intervalo configurado.
- Quarentena para registros inválidos.
- Retenção e particionamento de posições (30 dias).
- Log de importações e ingestões consultável no admin.

### 12.7 Gate de acesso à API de Teresina

Os dados atuais são de Teresina (`lat ≈ -5,16`, `lon ≈ -42,79`), fuso `America/Fortaleza`.

Checklist para considerar o acesso "total":

- [ ] Autorização formal e termos de uso comercial.
- [ ] Credenciais de produção e de teste.
- [ ] Documentação de cadastro e de tempo real.
- [ ] Rate limits e frequência de atualização.
- [ ] Cobertura ≥ 90% das linhas.
- [ ] Identificação de veículo e timestamps confiáveis.
- [ ] Contato de suporte e processo de incidentes.
- [ ] Revisão jurídica e de privacidade.

**Dual-run obrigatório:** rodar CSV × API em paralelo por 7 dias, comparando linhas, paradas, trajetos e posições, com mismatch < 1% antes de considerar a integração pronta.

Até o gate, `CsvDemoSource` mantém staging funcional.

---

## 13. Integração com o app Flutter

### 13.1 Implementações remotas

| Interface atual | Implementação remota |
|---|---|
| `AuthRepository` | `RemoteAuthRepository` |
| `LineSearchService` | `RemoteLineSearchService` |
| `BusStopService` | `RemoteBusStopService` |
| `LineStopsService` | `RemoteLineStopsService` |
| `RouteService` | `RemoteRouteService` |
| `TrackingService` | `RemoteTrackingService` |
| — | `FavoritesRepository` (novo) |
| — | `SubscriptionRepository` (novo) |
| — | `EntitlementsRepository` (novo) |
| — | `CityRepository` (novo) |
| — | `CityPreferenceRepository` (novo) |

### 13.2 Novos fluxos no app

- **Seleção de cidade:** `/select-city` sempre no primeiro acesso de uma conta sem preferência e quando a cidade atual estiver inativa.
- **Contexto de cidade:** client HTTP envia `citySlug` em todas as chamadas de catálogo.
- **Paywall:** trial de 7 dias (quando elegível), preço mensal vindo da loja, termos de renovação, links de privacidade, "Restaurar compras" e "Gerenciar assinatura".
- **Trial:** contador baseado em `current_period_end`; aviso nos dias finais.
- **Modo somente leitura:** após expiração, catálogo liberado, rastreamento e favoritos bloqueados com CTA persistente.
- **Heartbeat:** enviado a cada 30 s enquanto houver rastreamento ativo; parar no encerramento, no logout e ao expirar o acesso.
- **Banner de demonstração:** exibido sempre que `dataMode=demo`.
- **Troca de cidade:** encerrar sessões ativas, limpar caches de busca/rastreamento/favoritos e recarregar.

### 13.3 Requisitos de integração

- `Dio` com interceptors de auth, refresh automático, request ID, timeout e retry em GETs idempotentes.
- Tokens em `flutter_secure_storage`.
- Sem dependência de cookies ou de web.
- Mapear erros da API para exceções de domínio por `code`, nunca por texto.
- Feature flag para alternar entre assets e API durante a migração.
- Manter fakes nos testes.
- Mock server (Prism/WireMock) para testes de contrato.
- Logout limpa tokens, interrompe heartbeat e chama `resetDependencies()`.
- Nenhuma chamada de catálogo sem cidade.

### 13.4 Migração

1. Seed do catálogo a partir dos CSVs em staging.
2. Implementar endpoints de cidades e catálogo.
3. Criar client Dart e trocar services por feature flag.
4. Implementar auth real e remover `FakeAuthRepository`.
5. Implementar preferência de cidade e seletor.
6. Implementar entitlements, trial, paywall e modo somente leitura.
7. Implementar favoritos, cotas e heartbeat.
8. Remover assets quando a paridade estiver completa.

---

## 14. Segurança e privacidade

### 14.1 Ameaças e controles

| Ameaça | Controle |
|---|---|
| Account takeover por OTP | Código curto, hash, expiração, tentativas limitadas, rate limit |
| Força bruta | Rate limit por e-mail/IP/dispositivo, bloqueio temporário |
| Roubo de token | Access curto, refresh rotativo, revogação, device binding |
| Bypass de cota | Fonte de verdade no servidor, transações, idempotência |
| Bypass de trial | Elegibilidade controlada pela loja, sem trial no backend |
| Sessão órfã bloqueando o trial | Heartbeat e job de expiração |
| Webhook forjado | Verificação de assinatura, segredo, IP allowlist quando possível |
| Injeção SQL | ORM/consultas parametrizadas |
| Vazamento de PII | Minimização, logs sanitizados, acesso restrito |
| Scraping/abuso | Rate limit, autenticação, WAF opcional |
| DDoS | Cloudflare/provedor, limites, timeouts |
| Dado demo em produção | Flag obrigatória, guard na inicialização, teste de CI |
| Dependência vulnerável | `pip-audit`, Dependabot/Renovate |

### 14.2 LGPD

- Base legal documentada.
- Coleta mínima: e-mail e dados de uso necessários.
- Localização do usuário processada no dispositivo.
- Política de retenção:
  - OTP: expurgo após expiração.
  - Sessões e refresh tokens: expurgo após revogação/expiração.
  - Sessões de rastreamento: 90 dias após encerramento (métrica).
  - Posições: **30 dias**.
  - Logs: 30–90 dias, sem PII.
  - Conta: exclusão total sob solicitação; retenção mínima legal documentada.
- Exportação de dados disponível antes da exclusão.
- Aviso explícito de que a assinatura da loja não é cancelada pelo backend.
- Consentimento e transparência no app.
- Registro de tratamento e encarregado (DPO) quando aplicável.

---

## 15. Observabilidade e operação

### 15.1 SLOs iniciais

| SLO | Meta |
|---|---|
| Disponibilidade da API | 99,5% MVP / 99,9% alvo |
| Latência p95 catálogo | < 300 ms |
| Latência p95 posições | < 500 ms |
| Latência p95 heartbeat | < 150 ms |
| Taxa de erro 5xx | < 0,5% |
| Atraso de ingestão | < 2 minutos |
| Atraso de import de catálogo | < 1,5× o intervalo configurado |
| Entrega de OTP | > 98% |

### 15.2 Alertas

- API indisponível.
- Taxa de erro acima do limite.
- Latência acima do limite.
- Fila do Celery acumulada.
- Fonte de posições sem atualização.
- Import de catálogo atrasado ou falhando repetidamente.
- Sessões expiradas em volume anormal.
- Falha de webhook.
- Divergência entre entitlements e loja.
- Backup atrasado.
- Uso de disco/conexões do banco.

### 15.3 Runbooks

- Deploy e rollback.
- Restauração de backup.
- Incidente de fonte de dados.
- Falha de import de catálogo.
- Sessões órfãs ou heartbeat em massa falhando.
- Divergência de assinatura/entitlement.
- Rotação de secrets.
- Bloqueio de abuso.
- Exclusão de conta/LGPD.

### 15.4 Deploy

- Docker multi-stage.
- Gunicorn/Uvicorn.
- Migrations como release command.
- Health checks.
- Deploy staging em PR; produção em tag, após gate.
- Zero downtime com migrations compatíveis.
- Feature flags para billing, import e modo demo.

---

## 16. Testes e qualidade

### 16.1 Estratégia

| Tipo | Escopo |
|---|---|
| Unitário | Regras de negócio, validadores, serviços, cálculo de cota/fuso |
| Integração | Postgres/PostGIS real, Redis, API, Celery |
| Contrato | OpenAPI e client Dart |
| Concorrência | Cotas, sessão única no trial, favoritos |
| Carga | Ingestão e consultas |
| Segurança | OWASP ZAP baseline, `bandit`, `pip-audit` |
| Webhooks | Assinatura, idempotência, replay, transferência |
| Importação | Idempotência, diff, overrides, falha parcial |

### 16.2 Casos obrigatórios

- OTP expirado, reutilizado, tentativas e rate limit.
- Refresh rotativo e detecção de reuso.
- Cota diária e reset no fuso da cidade.
- Duas requisições concorrentes de rastreamento.
- Segunda sessão no trial retorna `409`.
- Sessão sem heartbeat expira e libera o slot.
- Retry com `Idempotency-Key` não conta duas vezes.
- Trocar de linha no trial consome novo rastreamento.
- Dois favoritos concorrentes no trial.
- Favoritar em `catalog_only` e `read_only` retorna `402`.
- Webhook duplicado, assinatura inválida e `TRANSFER`.
- Busca geoespacial por bbox e isolamento entre cidades.
- Preferência de cidade restaurada em novo login.
- Cidade inativa retorna erro estável.
- Import repetido sem duplicação.
- Item removido na origem fica inativo.
- Override fixado sobrevive ao import.
- Ingestão com dados inválidos e duplicados.
- Posição antiga marcada como `isStale=true`.
- Exclusão de conta encerra sessões e remove dados.
- Produção recusa `dataMode=demo`.

### 16.3 Definition of Done

- Código revisado.
- Testes unitários e de integração passando.
- `ruff`, `mypy` (quando aplicável), `manage.py check --deploy` sem erros.
- `makemigrations --check` sem alterações pendentes.
- OpenAPI atualizado.
- Documentação atualizada.
- Sem segredos ou PII em logs.
- Migrations testadas em staging.
- Monitoramento e alertas configurados.
- No app: `flutter analyze` e `flutter test` verdes.

---

## 17. Roadmap

Roadmap por gates, sem datas. M4–M6 não começam sem o acesso total à API de Teresina.

### M0 — Fundação

**Entregas**

- Projeto Django, settings por ambiente.
- Docker Compose com PostGIS, Redis e Mailpit.
- `/healthz`, `/readyz`, CI inicial.
- OpenAPI inicial.
- Guard de `dataMode`.
- Modelo `catalog_city` com Teresina e `timezone`.

**Pronto quando:** API sobe em staging, CI verde e Teresina cadastrada.

### M1 — Autenticação e preferências

**Entregas**

- OTP, JWT, refresh rotativo, logout.
- Rate limits.
- E-mail transacional.
- `GET/PUT /v1/me/preferences`.
- `GET /v1/me/entitlements` com `accessLevel`.
- Testes de segurança.

**Pronto quando:** app autentica de verdade, escolhe cidade e restaura a preferência em outro dispositivo.

### M2 — Catálogo e admin

**Entregas**

- Seed dos CSVs em staging.
- `GET /v1/cities` e endpoints de catálogo por cidade.
- Busca textual e geoespacial.
- Admin Django com grupos e auditoria.
- Importação de catálogo com diff e relatório.
- Overrides administrativos.
- Client Dart.

**Pronto quando:** app de staging busca linhas/paradas pela API, admin corrige dados e o import roda sem perder aliases.

### M3 — Demonstração de rastreamento

**Entregas**

- `CsvDemoSource` com timestamps deslocados.
- Pipeline de ingestão e `latest_position`.
- Frescura, `dataMode` e banner.
- Sessões de rastreamento com heartbeat (sem cobrança em staging).
- Testes de carga.

**Pronto quando:** app de staging mostra ônibus com `dataMode=demo`, sessões expiram corretamente e o banner aparece.

### M3.5 — Billing em sandbox (paralelo)

**Entregas**

- RevenueCat sandbox, produto `meubuzu_monthly` e oferta de 7 dias.
- Entitlement `premium`.
- Webhooks, idempotência e mapeamento de `accessLevel`.
- Paywall, restore e gerenciamento.

**Pronto quando:** compra, renovação, cancelamento, expiração e falha de cobrança funcionam em sandbox.

### M4 — Integração da API de Teresina

**Entregas**

- `TeresinaApiSource` para catálogo e posições.
- Sync de 30 s respeitando rate limit.
- Correção de aliases e mapeamento de veículos.

**Pronto quando:** checklist do gate de acesso cumprido e staging passa a operar com dados reais.

### M5 — Dual-run e validação

**Entregas**

- CSV × API em paralelo.
- Comparação de linhas, paradas, trajetos e posições.
- Correções de qualidade.
- Testes de falha da fonte.

**Pronto quando:** 7 dias de dual-run com mismatch < 1% e comportamento de falha validado.

### M6 — Produção

**Entregas**

- Billing em produção.
- Hardening, revisão de segurança e LGPD.
- Backups, runbooks e monitoramento finais.
- Termos, privacidade e app review.

**Pronto quando:** gate da seção 5.4 completo.

---

## 18. Riscos

| Risco | Probabilidade | Impacto | Mitigação |
|---|---|---|---|
| API de Teresina sem prazo | Alta | Alto | Staging com CSV; gate explícito; sem lançamento prematuro |
| API de Teresina com cobertura parcial | Média | Alto | Medir cobertura no spike; decidir lançamento por linha |
| API instável ou lenta | Média | Alto | Circuit breaker, cache, `isStale`, monitoramento |
| Import sobrescrever edição manual | Média | Médio | Override fixado por campo + auditoria |
| Alias local perdido no import | Baixa | Alto | Aliases em tabela separada, nunca importados |
| Import de catálogo atrasado | Média | Médio | Alerta por 1,5× intervalo; execução manual |
| Cota incorreta sob concorrência | Média | Alto | Transações, `select_for_update`, testes concorrentes |
| Sessão órfã bloqueando trial | Média | Alto | Heartbeat, TTL curto, job de expiração |
| Trial abusado por múltiplas contas | Baixa | Médio | Elegibilidade da loja, OTP verificado, rate limit |
| Rejeição do paywall pelas lojas | Média | Alto | IAP obrigatório, sem link externo, revisão prévia |
| Divergência RevenueCat × banco | Baixa | Alto | Idempotência, reconciliação, alerta |
| Vazamento de OTP/tokens | Baixa | Alto | Hash, expiração, rate limit, logs sanitizados |
| LGPD | Média | Alto | Minimização, retenção, exclusão total, revisão jurídica |
| Dado demo apresentado como real | Baixa | Alto | `dataMode` obrigatório, banner, guard de produção |
| Scope creep | Alta | Médio | MVP restrito, uma cidade, polling |
| Custo acima do previsto | Baixa | Médio | Free tiers, alertas, orçamento |
| Dependência de poucos mantenedores | Baixa | Médio | Stack mainstream, dependências consolidadas |

---

## 19. Custos iniciais

| Item | Custo mensal estimado |
|---|---|
| API (Fly.io GRU ou AWS `sa-east-1`) | US$ 0–25 |
| Postgres gerenciado com PostGIS | US$ 0–25 |
| Redis (Upstash/similar) | US$ 0–10 |
| E-mail transacional | US$ 0–10 |
| Sentry | US$ 0 |
| RevenueCat | Gratuito até o limite de receita |
| Domínio/SSL | ~US$ 15/ano |
| Staging | US$ 0–15 |

**Total:** US$ 0–85/mês no início. Free tiers mudam; validar antes de decidir.

---

## 20. Decisões

### 20.1 Resolvidas

| ID | Decisão | Resolução |
|---|---|---|
| D1 | Cidade de lançamento | **Teresina-PI** |
| D2 | Fonte de posições | Sempre PostgreSQL; CSVs só em staging; API de Teresina em produção |
| D3 | Seleção de cidade no app | Preferência no backend + cache local (ampliada por D12) |
| D4 | Comportamento após o trial | Catálogo somente leitura (D20) |
| D5 | Fuso e reset da cota | Fuso da cidade suportada (D30) |
| D6 | Retenção de posições e logs | 30 dias para posições; 30–90 dias para logs |
| D7 | Região de hospedagem | São Paulo (GRU / `sa-east-1`) como default |
| D8 | Pagamento web | Removido: sem web, sem Stripe (D22) |
| D9 | WebSocket | Polling no MVP |
| D10 | Assets offline como fallback | Apenas staging/demonstração |
| D11 | Cota por conta ou por dispositivo | Global por conta |
| D12 | Preferência de cidade | No backend, para sincronizar entre dispositivos |
| D13 | Lançamento catálogo-only | **Substituída por D17**: catálogo-only é apenas demonstração interna |
| D14 | Frequência de posições | 30 s, configurável por cidade |
| D15 | Retenção de posições | 30 dias |
| D16 | Cobrança em fase sem rastreamento | Gratuito, sem anúncios, favoritos ilimitados (staging/demo) |
| D17 | Condição de lançamento | Somente com acesso total à API de Teresina; sem data oficial |
| D18 | Modelo comercial | Trial de 7 dias + assinatura |
| D19 | Início do trial | Oferecido no primeiro rastreamento; começa na aceitação da oferta na loja |
| D20 | Após o trial | Catálogo somente leitura; rastreamento e escrita de favoritos bloqueados |
| D21 | Trial com ou sem cartão | **Com cartão**, via oferta introdutória da loja (RevenueCat) |
| D22 | Periodicidade e web | **Mensal**, sem web, sem Stripe |
| D23 | Favoritos antes do trial | **Não**; catálogo somente leitura até o trial |
| D25 | Antifraude de trial | Elegibilidade da loja + OTP verificado + rate limits + monitoramento |
| D26 | Período de graça | 3 dias, configurável no RevenueCat |
| D27 | Sessão ativa no fim do trial | Encerrada com `trial_expired`; novas posições bloqueadas |
| D28 | Heartbeat | App envia a cada 30 s; sessão expira após ~120 s sem heartbeat |
| D29 | Contagem de rastreamento | 1 rastreamento = 1 linha acompanhada; trial com 1 por vez |
| D30 | Fuso da cota | `America/Fortaleza` como campo da cidade suportada |
| D31 | Exclusão de conta | Exclusão total; trial permanece vinculado à conta da loja |
| D32 | Seletor com uma cidade | Sempre exibido no primeiro acesso |
| D33 | Dados importados e edição | Import periódico (semanal/mensal) é a fonte de verdade; admin edita qualquer campo |

### 20.2 Em aberto

| ID | Decisão | Recomendação | Bloqueia? |
|---|---|---|---|
| D24 | Preço mensal | Definir após staging, em BRL, nas lojas | Não |
| D34 | Usuário inelegível ao trial | Paywall apenas com mensal, sem prometer trial | Não |
| D35 | `TRANSFER` entre contas | Revogar da antiga, conceder à nova, auditar | Não |
| D36 | Reembolso/chargeback | Revogar entitlement ao receber notificação | Não |
| D37 | Analytics e consentimento | Provedor sem PII, com consentimento LGPD | Não |
| D38 | Termos, privacidade, suporte, DPO | Preparar antes do app review | **Sim** (M6) |
| D39 | Contas Apple/Google, fiscal, entidade legal | Resolver antes do lançamento | **Sim** (M6) |
| D40 | Política de mudança de preço | Aviso prévio; manter preço de quem já assina | Não |

### 20.3 Subdecisão confirmada (D33.1)

- **Precedência padrão:** o import é a fonte de verdade e sobrescreve campos não fixados.
- **Fixação:** o admin pode marcar "manter esta edição" por campo; o override sobrevive ao import e aparece com selo na interface.
- **Aviso:** edição sem fixação é explicitamente sinalizada como temporária na tela do admin.
- **Motivo:** atende "admin edita qualquer coisa" sem perder trabalho silenciosamente a cada importação.

---

## 21. Anexos

### 21.1 Mapeamento dos dados atuais

| Arquivo | Origem | Destino |
|---|---|---|
| `lines.csv` | `codigoLinha`, `nomeLinha`, `getOrigemIda`, `destinoIda`, `sgLinha` | `catalog_line.code`, `.name`, `.origin`, `.destination`, `.boarding_code` |
| `paradas.csv` | `id`, `codigo`, `denominacao`, `endereco`, `lat`, `long` | `catalog_stop.external_id`, `.code`, `.name`, `.address`, `.location` |
| `lines_paradas.json` | chave `sgLinha`, valores códigos de paradas | `catalog_line_stop` |
| `routes/<sgLinha>.csv` | `latitude,longitude` | `catalog_route.path` |
| `locations/*.csv` | label, `codigoLinha`, código do ônibus, `generatedAt`, lat, lon, `capturedAt` | `tracking_position` (demo) |

### 21.2 Glossário

| Termo | Definição |
|---|---|
| `codigoLinha` | Código operacional da linha (ex.: `3`) |
| `sgLinha` | Código de embarque/código curto da linha (ex.: `0001`) |
| OTP | One-Time Password; código temporário de uso único |
| Entitlement | Direito efetivo do usuário (trial, assinatura, limites) |
| `accessLevel` | Estado de acesso: `catalog_only`, `trial`, `paid`, `read_only` |
| `dataMode` | Origem do dado: `demo` (staging) ou `live` (produção) |
| Heartbeat | Sinal periódico que mantém a sessão de rastreamento viva |
| Override | Valor fixado pelo admin que prevalece sobre o import |
| Dual-run | Operação paralela CSV × API para validar qualidade |
| GTFS | General Transit Feed Specification |
| GTFS-RT | GTFS Realtime |
| PostGIS | Extensão geoespacial do PostgreSQL |
| PITR | Point-in-Time Recovery |
| RPO | Recovery Point Objective |
| RTO | Recovery Time Objective |
| SLO | Service Level Objective |
| IAP | In-App Purchase |

### 21.3 Referências

- Django: https://docs.djangoproject.com/
- Django REST Framework: https://www.django-rest-framework.org/
- PostGIS: https://postgis.net/documentation/
- GTFS: https://gtfs.org/
- GTFS Realtime: https://developers.google.com/transit/gtfs-realtime
- RevenueCat: https://www.revenuecat.com/docs/
- LGPD: https://www.gov.br/anpd/
- OWASP ASVS: https://owasp.org/www-project-application-security-verification-standard/

### 21.4 Histórico de versões

| Versão | Data | Alteração |
|---|---|---|
| 1.0 | 16/11/2026 | Versão inicial do PRD |
| 1.8 | 16/11/2026 | Consolidação das decisões D1–D33: Teresina como cidade de lançamento, staging com CSVs, gate de acesso à API, catálogo gratuito somente leitura, trial de 7 dias com cartão via loja, assinatura mensal sem web, favoritos condicionados ao trial, heartbeat e cotas, fuso por cidade, exclusão total de conta, seletor de cidade e import periódico com override administrativo |

---

## 22. Próximos passos imediatos

1. **Preservar o Vaden:** criar branch/tag `backend-vaden` antes de substituir `backend/`.
2. **Scaffold Django:** projeto, settings por ambiente, Docker Compose com PostGIS/Redis/Mailpit, `/healthz` e guard de `dataMode`.
3. **Modelo de cidades:** `catalog_city` com Teresina, `America/Fortaleza` e `import_interval`.
4. **Autenticação OTP:** implementar e testar antes de integrar o app.
5. **Preferência de cidade:** endpoints e teste de restauração em segundo dispositivo.
6. **Seed do catálogo:** importar `lines.csv`, `paradas.csv`, `lines_paradas.json` e `routes/*.csv` em staging.
7. **Import de catálogo:** diff, idempotência, desativação e overrides.
8. **Replay de posições:** `CsvDemoSource` com timestamps deslocados e `dataMode=demo`.
9. **Sessões e heartbeat:** cotas, sessão única no trial e expiração automática.
10. **Billing em sandbox:** RevenueCat, produto mensal, oferta de 7 dias e webhooks.
11. **Contato com a SMT/Prefeitura de Teresina:** documentação, credenciais e termos.
12. **Atualizar documentação:** `README.md`, `CLAUDE.md`, `AGENTS.md`, `backend/README.md` e `app/README.md`.

