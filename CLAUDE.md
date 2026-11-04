# MeuBuzu - Projeto de Localização de Ônibus em Tempo Real

Este projeto é o aplicativo MeuBuzu, que permite aos usuários acompanhar a localização de ônibus em tempo real, planejar viagens e obter informações sobre linhas e paradas.

## 🛠 Tecnologias e Estrutura
- **Frontend:** Flutter (Android, iOS, Web)
- **Backend:** Dart usando o framework [Vaden](https://github.com/Flutterando/vaden)
- **Estrutura de Diretórios:**
  - `backend/`: Contém toda a lógica de servidor e APIs.
  - `app/`: Contém o aplicativo Flutter para Android, iOS e web.

## 🚀 Comandos de Desenvolvimento (Padrão Flutter/Dart)
*Nota: Ajustar conforme a configuração específica do projeto.*
- **Executar App:** `flutter run`
- **Testes Unitários:** `flutter test`
- **Análise de Código:** `flutter analyze`
- **Build de Produção:** `flutter build`

## 📏 Padrões de Código e Diretrizes
- **Linguagem:** Dart
- **UI:** Flutter
- **Arquitetura:** Seguir padrões de Clean Architecture e separação clara entre lógica de negócio e interface.
- **Performance:** As atualizações de posição no mapa devem ser otimizadas para não redesenhar elementos desnecessários.
- **Privacidade:** Sempre explicar o uso de localização antes de solicitar permissão.
- **Segurança:** **Jamais** registrar códigos de acesso temporários em logs.

## 📋 Regras de Negócio e Limitações
- **Modo de Teste (7 dias):**
  - Limite de 1 linha acompanhada simultaneamente.
  - Limite de 5 rastreamentos iniciados por dia.
  - Limite de 1 linha favorita. Ao tentar favoritar uma segunda, o app mostra a oferta de assinatura; o usuário pode remover o favorito atual e favoritar outra linha sem custo e sem consumir rastreamento.
- **Assinatura Paga:**
  - Sem limite diário de rastreamentos.
  - Várias linhas acompanhadas simultaneamente.
  - Favoritos ilimitados.
  - Sem anúncios e com cache local de dados cadastrais.
- **Favoritos:** Favoritar, desfavoritar e abrir uma linha favorita não consome a cota de rastreamentos nem substitui o limite de linhas acompanhadas ao mesmo tempo.
- **Acesso:** Exige autenticação por e-mail e código temporário (não é senha permanente).

## 🎯 Objetivos Principais
- Exibir ônibus em operação em um mapa em tempo real.
- Buscar linhas e paradas por nome, número ou ID.
- Fornecer estados claros para carregamento, falta de conexão e ausência de resultados.

## 📝 Notas de Desenvolvimento
- **Cache:** O cache Premium cobre dados que mudam pouco (paradas, linhas, características). As posições dos veículos continuam sendo atualizadas online.
- **Acessibilidade:** Priorizar suporte a leitores de tela e navegação por teclado.
