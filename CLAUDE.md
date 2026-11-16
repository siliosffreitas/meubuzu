# MeuBuzu - Projeto de Localização de Ônibus em Tempo Real

Este projeto é o aplicativo MeuBuzu, que permite aos usuários acompanhar a localização de ônibus em tempo real e consultar informações sobre linhas e paradas. A cidade de lançamento é **Teresina-PI**.

## 🛠 Tecnologias e Estrutura
- **Frontend:** Flutter (Android e iOS). Não há versão web no lançamento.
- **Backend:** Python + Django 5.2 LTS + Django REST Framework + PostgreSQL/PostGIS + Redis + Celery. Substitui o protótipo em Dart/Vaden.
- **Cobrança:** RevenueCat, via App Store e Google Play. Assinatura mensal.
- **Fonte de dados:** API de Teresina. Os CSVs de `app/assets` são usados apenas em staging, com `dataMode=demo`.
- **Estrutura de Diretórios:**
  - `backend/`: lógica de servidor e APIs.
  - `app/`: aplicativo Flutter.
  - `docs/PRD-backend-meubuzu.md`: PRD do backend e decisões D1–D40.

## 🚀 Comandos de Desenvolvimento

### App Flutter (dentro de `app/`)
- **Executar:** `flutter run`
- **Testes:** `flutter test`
- **Análise:** `flutter analyze`
- **Formatação:** `dart format lib test`

### Backend (dentro de `backend/`, após o scaffold Django)
- **Servidor:** `python manage.py runserver`
- **Testes:** `python manage.py test`
- **Migrations:** `python manage.py makemigrations` e `python manage.py migrate`
- **Checks:** `ruff check .` e `python manage.py check --deploy`
- **Import de catálogo:** `python manage.py import_catalog --city teresina`

> O `backend/` atual ainda contém o protótipo Dart/Vaden. Não edite `backend/lib/vaden_application.dart` à mão: ele é gerado.

## 📏 Padrões de Código e Diretrizes
- **Linguagem do app:** Dart; **linguagem do backend:** Python.
- **UI:** Flutter.
- **Arquitetura:** separação clara entre UI, view models, repositórios e serviços. No backend, apps Django por domínio (`accounts`, `catalog`, `tracking`, `favorites`, `billing`, `common`).
- **Performance:** as atualizações de posição no mapa devem ser otimizadas para não redesenhar elementos desnecessários.
- **Privacidade:** sempre explicar o uso de localização antes de solicitar permissão.
- **Segurança:** **jamais** registrar códigos de acesso temporários, tokens ou dados pessoais em logs.
- **Idioma:** textos de interface e comentários em português; identificadores em inglês.

## 📋 Regras de Negócio e Limitações

### Estados de acesso
- `catalog_only`: catálogo gratuito somente leitura; rastreamento e favoritos bloqueados.
- `trial`: 7 dias; 1 linha por vez, 5 rastreamentos/dia e 1 favorito.
- `paid`: várias linhas, rastreamentos ilimitados e favoritos ilimitados; sem anúncios.
- `read_only`: após o trial; catálogo e favoritos existentes somente leitura.

### Catálogo gratuito
- Buscar linhas e paradas, ver detalhes, itinerário e paradas no mapa não exige pagamento.
- O catálogo exige autenticação, como o restante do app.

### Teste de 7 dias
- É **oferecido no primeiro rastreamento**: o usuário explora o catálogo sem prazo e encontra a oferta ao tentar acompanhar uma linha ou favoritar.
- É concedido **pela loja, com cartão**, via oferta introdutória gerenciada pelo RevenueCat. O teste só começa quando o usuário aceita a oferta.
- A elegibilidade é da loja: excluir a conta no backend não reinicia o teste.
- Durante o teste: 1 linha acompanhada por vez, até 5 rastreamentos iniciados por dia e 1 favorito.
- Ao fim do teste sem assinatura, o app entra em `read_only`.

### Assinatura
- Mensal apenas. Sem plano anual, sem web e sem Stripe.
- Gerenciar, cancelar e restaurar compras são responsabilidades da loja.
- Nenhuma compra informada pelo app é aceita como verdade; o backend só confia em webhooks do RevenueCat.

### Rastreamento e cotas
- **1 rastreamento = 1 linha acompanhada.** Duas linhas simultâneas, no plano pago, contam como dois rastreamentos.
- Fechar e reabrir a mesma linha conta como um novo rastreamento.
- Retry com a mesma `Idempotency-Key` e reabertura de sessão ainda viva **não** contam.
- A cota é **global por conta**, independente de cidade.
- O dia da cota usa o fuso da cidade selecionada (`America/Fortaleza` para Teresina), definido no cadastro da cidade e nunca fixo no código.
- No trial há no máximo **uma sessão ativa**; o app envia heartbeat a cada 30 s e o backend expira a sessão após ~120 s sem sinal.
- Encerrar, trocar de linha ou expirar o trial fecha a sessão e libera o slot.

### Favoritos
- Antes do teste: bloqueado; o app mostra a oferta de assinatura.
- No teste: 1 favorito, com troca livre e sem consumir cota.
- Pago: ilimitado.
- Após o teste: somente leitura.
- Favoritar, desfavoritar e abrir uma linha favorita não consome cota nem substitui o limite de linhas acompanhadas.

### Cidade
- Teresina é a única cidade ativa no lançamento.
- A tela de seleção de cidade aparece mesmo com uma única cidade.
- A preferência é salva no backend e restaurada em outro dispositivo.
- Trocar de cidade encerra rastreamentos ativos e limpa caches locais.

### Privacidade
- Exclusão de conta remove todos os dados do usuário; a assinatura da loja não é cancelada automaticamente e o app deve avisar.
- Exportação de dados disponível antes da exclusão.
- Localização do usuário é processada no dispositivo; o backend não recebe a posição do aparelho.

## 🎯 Objetivos Principais
- Exibir ônibus em operação em um mapa em tempo real.
- Buscar linhas e paradas por nome, número ou ID.
- Fornecer estados claros para carregamento, falta de conexão e ausência de resultados.
- Informar a origem e o horário dos dados, sem apresentar posição antiga como atual.

## 📝 Notas de Desenvolvimento
- **Cache:** o cache de dados cadastrais (paradas, linhas, características) é um benefício do plano pago. As posições dos veículos continuam sendo atualizadas online.
- **Demonstração:** staging usa CSVs com `dataMode=demo` e exibe banner de dados de demonstração. Produção nunca aceita dados demo.
- **Import de catálogo:** roda em ciclo semanal (default) ou mensal por cidade. Edições do admin sobrevivem ao import apenas quando marcadas como "manter esta edição".
- **Lançamento:** não há data oficial; depende do acesso total à API de Teresina.
- **Acessibilidade:** priorizar suporte a leitores de tela e tamanhos de texto.
