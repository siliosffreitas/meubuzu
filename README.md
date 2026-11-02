O MeuBuzu é um aplicativo para mostrar a localização dos ônibus em tempo real.
# MeuBuzu
O MeuBuzu ajuda as pessoas a planejar suas viagens de ônibus, acompanhando veículos em tempo real e consultando informações de linhas e paradas.

## Objetivos

- Exibir ônibus em operação em um mapa, com posição atualizada em tempo real quando os dados estiverem disponíveis.
- Ajudar o usuário a encontrar linhas, paradas e informações úteis para sua viagem.
- Oferecer uma experiência simples e consistente em dispositivos móveis e na web.

## Funcionalidades principais

### Mapa e acompanhamento

- Mostrar a localização dos ônibus e as linhas atendidas.
- Permitir selecionar uma linha e acompanhar seus veículos.
- Exibir paradas no mapa e os detalhes de cada parada.
- Informar quando os dados de localização foram atualizados, evitando apresentar dados antigos como se fossem atuais.

### Busca e informações

- Buscar linhas e paradas por nome, número ou identificador.
- Exibir detalhes da linha, incluindo itinerário e paradas, conforme os dados disponíveis.
- Exibir detalhes da parada e previsões de chegada quando a fonte de dados oferecer essa informação.
- Apresentar estados claros para carregamento, falta de conexão, ausência de resultados e indisponibilidade dos dados.

### Conta e acesso

- O acesso ao aplicativo exige uma conta autenticada.
- O usuário informa seu e-mail e recebe um código temporário para confirmar o endereço e entrar.
- O código deve expirar e só pode ser usado uma vez. Ele funciona como código de verificação, não como senha permanente.
- Permitir solicitar um novo código e informar quando o código anterior expirou.

## Planos
## Assinatura

O MeuBuzu não terá um plano gratuito permanente. Novos usuários podem acessar o aplicativo durante um teste de 7 dias, com as mesmas limitações do antigo plano Free. Depois do teste, é necessária uma assinatura paga para continuar usando o serviço.

| Recurso | Teste de 7 dias | Assinatura paga |
| --- | --- | --- |
| Linhas acompanhadas simultaneamente | 1 | Várias |
| Rastreamentos iniciados | Até 5 por dia | Sem limite diário |
| Busca de localidades, linhas e paradas | Não consome a cota de rastreamentos | Não consome a cota de rastreamentos |
| Anúncios | Exibe anúncios | Sem anúncios |
| Favoritar linhas | Não incluído | Incluído |

Pesquisar ou consultar localidades, linhas e paradas não consome a cota. Cada vez que o usuário inicia o rastreamento de uma linha, essa ação conta como um rastreamento, inclusive quando a linha é escolhida para chegar a uma localidade pesquisada. No teste, o usuário pode acompanhar apenas uma linha por vez e iniciar até 5 rastreamentos por dia.

- Informar com clareza a data de término do teste, o preço da assinatura e as condições de cobrança antes de iniciar o período de teste.
- Permitir gerenciar ou cancelar a assinatura e restaurar compras, conforme as regras da plataforma de pagamento.

## Ideias para evolução

As sugestões abaixo ampliam o produto; não significam que já estejam implementadas.

### Para quem usa o transporte

- **Alertas de viagem:** avisar sobre interrupções, desvios, alterações de itinerário e mudanças no serviço das linhas favoritas.
- **Previsão de chegada:** mostrar estimativas por parada, com indicação de precisão ou indisponibilidade.
- **Planejador de viagem:** combinar caminhada, paradas e linhas para sugerir opções de trajeto e duração estimada.
- **Lembretes de descida:** notificar quando o usuário estiver próximo da parada escolhida, com permissão explícita de localização.
- **Acessibilidade:** oferecer navegação compatível com leitores de tela, bom contraste, textos redimensionáveis e informações sobre acessibilidade das paradas quando disponíveis.
- **Compartilhamento:** permitir compartilhar uma linha, parada ou previsão por link.
- **Feedback sobre dados:** receber relatos de veículo ausente, posição incorreta ou informação desatualizada.

### Para tornar o serviço confiável

- Mostrar a origem e o horário da última atualização dos dados.
- Monitorar falhas de ingestão e sinalizar indisponibilidade sem inventar posições ou previsões.
- Definir uma estratégia de cache para abrir linhas e paradas recentes quando a conexão estiver instável.
- Criar ferramentas administrativas para revisar fontes de dados, linhas, paradas e avisos operacionais.
- Medir buscas e limites de uso com regras consistentes entre dispositivos, sem depender apenas de contadores locais.
- Medir inícios de rastreamento e limites de uso com regras consistentes entre dispositivos, sem depender apenas de contadores locais.
- Medir o uso e validar o estado da assinatura de forma consistente entre dispositivos, sem depender apenas de informações locais.

### Conta e assinatura
### Conta e assinatura

- Consultar a data de término do teste ou de renovação da assinatura e restaurar compras.
- Oferecer uma forma clara de cancelar a assinatura.
- Informar ao usuário antes do início do teste se será necessário cadastrar um meio de pagamento e se a assinatura será cobrada automaticamente ao fim dos 7 dias.
- Proteger dados pessoais, limitar tentativas de envio de códigos e explicar como localização e telemetria são usadas.

## Requisitos não funcionais

- **Plataformas:** compartilhar a maior parte da interface e da lógica entre Android, iOS e web usando Flutter.
- **Desempenho:** manter o mapa utilizável com muitos veículos e atualizar posições sem redesenhar elementos desnecessariamente.
- **Confiabilidade:** tratar erros de rede, permissões negadas e dados incompletos sem bloquear a navegação.
- **Privacidade:** solicitar localização apenas para recursos que precisem dela e explicar seu uso antes da permissão.
- **Segurança:** proteger sessões, códigos de acesso e dados da conta; nunca registrar códigos temporários em logs.
- **Acessibilidade:** oferecer suporte a leitores de tela, navegação por teclado na web e preferências de tamanho de texto.

## Decisões em aberto

- Quais cidades e fontes de dados serão atendidas no lançamento? Há disponibilidade de localização em tempo real, itinerários e previsões?
- Qual será o horário e o fuso de renovação da cota diária de 5 rastreamentos durante o teste?
- Quais meios de pagamento e regras de renovação serão usados para a assinatura?
- O teste de 7 dias exigirá o cadastro de um meio de pagamento? Haverá cobrança automática ao final do período?
- O que acontecerá com os dados do usuário e suas linhas favoritas se o teste terminar sem a contratação de uma assinatura?
- O planejador de viagem e os alertas entram no lançamento ou ficam para uma fase posterior?

## Tecnologia

O aplicativo será desenvolvido em Flutter para oferecer uma experiência consistente em dispositivos móveis e também na web. O backend ficará no diretório `backend/` e será escrito em Dart usando o framework [Vaden](https://github.com/Flutterando/vaden). A disponibilidade de recursos como mapas, notificações e compras pode variar por plataforma e deve ser validada durante a implementação.