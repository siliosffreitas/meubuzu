# Backend do MeuBuzu

## Tecnologia

O backend será desenvolvido em **Python 3.12+** com **Django 5.2 LTS**, **Django REST Framework**, **PostgreSQL + PostGIS**, **Redis** e **Celery**. Ele substitui o protótipo em Dart/Vaden que ainda está em `backend/`.

As decisões completas — modelo, API, cotas, billing, importação e gate de lançamento — estão em `docs/PRD-backend-meubuzu.md`.

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
