O MeuBuzu é um aplicativo para mostrar a localização dos ônibus em tempo real.
# MeuBuzu
O MeuBuzu ajuda as pessoas a planejar suas viagens de ônibus, acompanhando veículos em tempo real e consultando informações de linhas e paradas.

## Objetivos

- Exibir ônibus em operação em um mapa, com posição atualizada em tempo real quando os dados estiverem disponíveis.
- Ajudar o usuário a encontrar linhas, paradas e informações úteis para sua viagem.
- Oferecer uma experiência simples e consistente em Android e iOS.

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

## Planos e assinatura

O MeuBuzu não terá plano gratuito com rastreamento em tempo real. O catálogo (busca, linhas, paradas e itinerários) é aberto em **modo somente leitura**. O rastreamento é liberado por um **teste de 7 dias** e, depois, por **assinatura mensal**.

| Recurso | Catálogo gratuito | Teste de 7 dias | Assinatura mensal | Após o teste |
| --- | --- | --- | --- | --- |
| Buscar linhas e paradas | Sim | Sim | Sim | Sim |
| Ver itinerário e paradas no mapa | Sim | Sim | Sim | Sim |
| Acompanhar ônibus em tempo real | Não | 1 linha por vez | Várias linhas | Não |
| Rastreamentos iniciados | 0 | Até 5 por dia | Sem limite diário | 0 |
| Favoritos | Não | 1 linha | Ilimitados | Somente leitura |
| Anúncios | Sem anúncios | A definir | Sem anúncios | A definir |

Pesquisar ou consultar localidades, linhas e paradas não consome a cota. Cada vez que o usuário inicia o rastreamento de uma linha, essa ação conta como um rastreamento, inclusive quando a linha é escolhida para chegar a uma localidade pesquisada. No teste, o usuário pode acompanhar apenas uma linha por vez e iniciar até 5 rastreamentos por dia.

Regras do modelo de acesso:

- **O teste começa no primeiro rastreamento.** O usuário pode explorar o catálogo sem prazo. Quando tenta acompanhar uma linha, o app apresenta a oferta de 7 dias.
- **O teste é oferecido pela loja, com cartão.** A oferta introdutória é gerenciada pela App Store ou Google Play via RevenueCat. Ela só começa quando o usuário aceita a oferta; recusar mantém o catálogo somente leitura.
- **A elegibilidade é da loja.** Quem já usou o teste não recebe a oferta de novo. Excluir a conta no app não reinicia a elegibilidade.
- **Assinatura mensal, sem plano anual e sem cobrança fora das lojas.** Restaurar compras e cancelar são feitos pela loja.
- **Após o teste**, o app continua útil em modo somente leitura: busca, linhas, paradas, itinerários e favoritos existentes. O rastreamento e a edição de favoritos ficam bloqueados com oferta de assinatura.
- **1 rastreamento = 1 linha acompanhada.** Duas linhas ao mesmo tempo, no plano pago, contam como dois rastreamentos. Fechar e abrir a mesma linha novamente conta como um novo rastreamento.
- **A cota é global por conta**, independente de cidade, e reinicia à meia-noite no fuso da cidade selecionada (Teresina: `America/Fortaleza`).
- **A cidade é escolhida no app.** Teresina é a cidade de lançamento; a escolha é salva no backend e restaurada em outro dispositivo.

O cache de dados cadastrais de paradas, linhas e ônibus está previsto para o plano pago. As posições dos veículos continuam sendo atualizadas online.

- Informar com clareza a data de término do teste, o preço da assinatura e as condições de cobrança antes de iniciar o período de teste.
- Permitir gerenciar ou cancelar a assinatura e restaurar compras, conforme as regras da plataforma de pagamento.

### Favoritos no teste de 7 dias

Antes do teste, o catálogo é somente leitura e **não é possível favoritar**. Ao tocar em favoritar, o app apresenta a oferta de 7 dias. O teste permite favoritar **uma linha**. O favorito é o atalho para o trajeto do dia a dia e serve como demonstração do benefício: o usuário sente o valor de ter a linha sempre à mão e, ao tentar favoritar uma segunda, encontra a oferta de assinatura. O limite existe para que o hábito criado no teste não se sustente sem a assinatura.

Regras de comportamento:

- Antes do teste, favoritar abre a oferta de assinatura; o favorito não é aplicado.
- Ao tentar favoritar uma segunda linha no teste, o app não aplica o favorito e apresenta a oferta de assinatura, explicando que o teste inclui apenas uma linha favorita.
- A oferta deve permitir remover a linha já favoritada e favoritar outra, sem cobrança e sem consumir rastreamento. O usuário nunca fica impedido de trocar de favorito.
- A linha favoritada não precisa estar sendo rastreada no momento. Favoritar, desfavoritar e abrir a linha favoritada não consome a cota de rastreamentos.
- O favorito não substitui a regra de uma linha acompanhada por vez. Para acompanhar uma linha diferente da favoritada, o usuário inicia um novo rastreamento, respeitando o limite de 5 por dia.
- Depois do teste, os favoritos existentes ficam **somente leitura**: podem ser consultados, mas não podem ser adicionados, removidos ou trocados até a assinatura.
- A assinatura paga remove o limite de favoritos e o app deve deixar a diferença explícita na tela de planos, antes do fim do teste.

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

- Consultar a data de término do teste ou de renovação da assinatura e restaurar compras.
- Oferecer uma forma clara de cancelar a assinatura.
- Informar ao usuário antes do início do teste se será necessário cadastrar um meio de pagamento e se a assinatura será cobrada automaticamente ao fim dos 7 dias.
- Proteger dados pessoais, limitar tentativas de envio de códigos e explicar como localização e telemetria são usadas.

## Requisitos não funcionais

- **Plataformas:** compartilhar a maior parte da interface e da lógica entre Android e iOS usando Flutter. O app é mobile-first; não há versão web no lançamento.
- **Desempenho:** manter o mapa utilizável com muitos veículos e atualizar posições sem redesenhar elementos desnecessariamente.
- **Confiabilidade:** tratar erros de rede, permissões negadas e dados incompletos sem bloquear a navegação.
- **Privacidade:** solicitar localização apenas para recursos que precisem dela e explicar seu uso antes da permissão.
- **Segurança:** proteger sessões, códigos de acesso e dados da conta; nunca registrar códigos temporários em logs.
- **Acessibilidade:** oferecer suporte a leitores de tela e preferências de tamanho de texto.

## Decisões em aberto

- Qual será o preço da assinatura mensal? O valor será configurado em BRL na App Store e no Google Play.
- Haverá anúncios durante o teste de 7 dias? O plano pago é sem anúncios.
- Qual provedor de analytics será usado e com qual base legal?
- Quais serão os termos de uso, a política de privacidade e o canal de suporte?
- Como tratar transferência de assinatura entre contas, reembolsos e chargebacks?
- Quando o app será lançado? Não há data: o lançamento depende do acesso total à API de Teresina.

## Tecnologia

O aplicativo é desenvolvido em Flutter para Android e iOS. O backend fica no diretório `backend/` e será implementado em **Python + Django 5.2 LTS + Django REST Framework + PostgreSQL/PostGIS**, com Redis e Celery para cache e tarefas assíncronas. O protótipo atual em Dart/Vaden será substituído; as decisões de backend estão em `docs/PRD-backend-meubuzu.md`.

A fonte de dados é a API de Teresina. Enquanto o acesso não é liberado, o backend usa os CSVs de `app/assets` apenas em staging, com `dataMode=demo` e aviso explícito de dados de demonstração.