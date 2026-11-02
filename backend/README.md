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
