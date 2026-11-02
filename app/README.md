# Aplicativo MeuBuzu

## Tecnologia

O aplicativo será desenvolvido com **Flutter** e **Dart**, compartilhando a maior parte do código entre Android, iOS e web.

## Arquitetura

O projeto seguirá a arquitetura recomendada pela equipe do Flutter, conforme a [documentação oficial de arquitetura de aplicações](https://docs.flutter.dev/app-architecture). A organização separa responsabilidades em camadas e por funcionalidade.

### Camada de interface (UI)

- **Views** e widgets exibem o estado da aplicação e encaminham as interações do usuário.
- **ViewModels** mantêm e transformam o estado necessário para cada tela, coordenando as ações da interface com a camada de dados.
- Widgets devem permanecer simples, sem concentrar regras de negócio.

Essa separação segue o padrão **MVVM** (Model-View-ViewModel).

### Camada de dados

- **Repositories** são a fonte única de verdade dos dados utilizados pelo app e isolam a interface e as regras da aplicação dos detalhes de acesso aos dados.
- **Services** encapsulam integrações com fontes de dados, como a API do backend, armazenamento local e recursos da plataforma.

### Camada de domínio

Uma camada de domínio ou casos de uso poderá ser adicionada quando houver regras de negócio complexas no cliente ou lógica compartilhada entre vários ViewModels. Ela não será criada por padrão para operações simples.

### Fluxo de dados

O fluxo será unidirecional: as Views enviam ações aos ViewModels; os ViewModels acionam os Repositories; os Repositories usam Services para acessar ou atualizar dados. O estado atualizado retorna pelo ViewModel e é exibido pela View. Os dados devem ter uma fonte única de verdade, evitando alterações independentes espalhadas pela interface.

### Princípios de implementação

- Separar a lógica de apresentação, as regras de negócio e o acesso a dados.
- Usar injeção de dependências para conectar os componentes sem dependências globais desnecessárias.
- Manter modelos de dados imutáveis sempre que apropriado.
- Testar Views, ViewModels, Repositories e Services de forma isolada e em conjunto.

A estratégia de gerenciamento de estado e as bibliotecas de navegação e injeção de dependências serão definidas durante a implementação, seguindo as necessidades do projeto e as recomendações oficiais.
