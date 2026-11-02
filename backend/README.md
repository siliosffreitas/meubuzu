# Backend do MeuBuzu

## Tecnologia

O backend será desenvolvido em **Dart** usando o framework [Vaden](https://github.com/Flutterando/vaden).

## Armazenamento de dados

### Dados cadastrais e operacionais

Usar **PostgreSQL** como fonte de verdade para os dados estruturados do produto, como ônibus e suas características, paradas, linhas e variantes de itinerário. A extensão [PostGIS](https://postgis.net/) permitirá armazenar e consultar dados geográficos, como coordenadas de paradas e trajetos.

A relação entre ônibus e linha pode mudar conforme o dia ou a operação. Ela deve ser armazenada separadamente dos dados permanentes do veículo, com período de validade, para representar mudanças e preservar o histórico.

### Posições dos veículos

As posições recebidas frequentemente devem ser armazenadas como eventos de rastreamento, identificados pelo veículo e pelo horário da observação, com coordenadas e outros dados disponíveis, como velocidade e direção.

Se o produto precisar consultar o histórico de posições, usar **TimescaleDB**, extensão de séries temporais do PostgreSQL, para esse fluxo. Os dados cadastrais e o rastreamento podem compartilhar a mesma infraestrutura PostgreSQL, mantendo tabelas e responsabilidades separadas. Se for necessário somente consultar a posição atual, uma tabela PostgreSQL otimizada para esse estado pode ser suficiente no início.

O Redis poderá ser considerado posteriormente como cache ou apoio à distribuição de atualizações em tempo real, mas não será a fonte permanente dos dados.

### Usuários e autenticação

Os dados da conta, como identificador, e-mail verificado e datas de criação e atualização, serão armazenados no **PostgreSQL**. Os códigos temporários enviados por e-mail para autenticação devem ter validade curta, ser de uso único e nunca ser armazenados em texto aberto ou registrados em logs. Registros expirados devem ser removidos; tentativas de envio e validação também precisam ser limitadas.

### Assinaturas e pagamentos

O estado da assinatura e do acesso do usuário será mantido no **PostgreSQL**, associado à conta. Os registros devem incluir somente os dados necessários para controlar o acesso, como plano, status, início e término do teste ou assinatura, além de identificadores fornecidos pelo provedor de cobrança.

O backend deve validar compras e mudanças na assinatura com o provedor de cobrança ou com a loja da plataforma, por meio de APIs de servidor e notificações verificadas. O app cliente não deve ser a fonte de verdade para conceder acesso. O provedor de cobrança ainda será definido.

O MeuBuzu não armazenará números completos de cartão nem códigos de segurança (CVV). Quando necessário, poderão ser armazenados identificadores ou tokens emitidos pelo provedor, sem dados que permitam recuperar o número do cartão. O processamento dos dados de cartão ficará a cargo do provedor de pagamento ou da loja da plataforma.
