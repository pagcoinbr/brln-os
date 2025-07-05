# Setup Docker Intelligent (Rust)

Uma reimplementação em Rust do script `setup-docker-intelligent.sh` com funcionalidades aprimoradas e interface mais robusta.

## Características

- **Parser de docker-compose.yml**: Analisa automaticamente o arquivo docker-compose.yml para descobrir serviços e dependências
- **Interface interativa**: Menu colorido e intuitivo para seleção de serviços
- **Resolução automática de dependências**: Inclui automaticamente serviços dependentes
- **Validação de recursos**: Verifica a existência de Dockerfiles e binários necessários
- **Configuração automática**: Cria usuários, grupos, diretórios e arquivos de configuração
- **Modo de teste individual**: Permite testar serviços isoladamente
- **Progress bars**: Indicadores visuais de progresso durante operações longas
- **Logging estruturado**: Sistema de logs com diferentes níveis de verbosidade

## Pré-requisitos

- Rust 1.70+ (https://rustup.rs/)
- Docker e Docker Compose
- Permissões sudo (para criar usuários e diretórios)
- jq (opcional, para funcionalidades avançadas)

## Instalação

1. Clone o repositório ou navegue até o diretório `container/`
2. Compile o projeto:

```bash
cd container/
cargo build --release
```

3. O executável estará disponível em `target/release/setup-docker-intelligent`

## Uso

### Modo Interativo (Padrão)

```bash
cargo run
# ou
./target/release/setup-docker-intelligent
```

### Modo Linha de Comando

```bash
# Executar serviços específicos
cargo run -- --services "lnd,elements,peerswap"

# Modo automático (detecta serviços com Dockerfile)
cargo run -- --mode auto

# Incluir dependências automaticamente
cargo run -- --services "lnd" --deps

# Modo verbose para debugging
cargo run -- --verbose --services "lnd"
```

### Opções de Linha de Comando

- `--verbose, -v`: Habilita saída detalhada para debugging
- `--mode, -m`: Define o modo de operação (`interactive`, `auto`)
- `--services, -s`: Lista de serviços separados por vírgula
- `--deps, -d`: Inclui dependências automaticamente
- `--help, -h`: Mostra ajuda

## Funcionalidades

### 1. Descoberta Automática de Serviços

O programa analisa:
- **docker-compose.yml**: Extrai serviços, dependências, portas e volumes
- **Arquivos service.json**: Carrega configurações específicas de cada serviço

### 2. Menu Interativo

Opções disponíveis:
- Seleção individual de serviços
- Todos os serviços
- Detecção automática (apenas serviços com Dockerfile existente)
- Modo de teste individual

### 3. Resolução de Dependências

Quando um serviço é selecionado, o programa:
- Identifica dependências no docker-compose.yml
- Resolve a árvore completa de dependências
- Inicia serviços na ordem correta

### 4. Configuração Automática

Para cada serviço, o programa:
- Cria usuários e grupos do sistema
- Cria diretórios de dados com permissões corretas
- Copia e configura arquivos de configuração
- Define permissões específicas (600 para passwords, 755 para scripts)

### 5. Validação de Recursos

Verifica a existência de:
- Dockerfiles necessários
- Binários requeridos
- Arquivos de configuração

### 6. Execução Docker Compose

- Para containers existentes
- Executa build dos serviços selecionados
- Inicia serviços com `docker-compose up -d`
- Exibe status final dos containers

## Estrutura de Arquivos

```
container/
├── Cargo.toml              # Configuração do projeto Rust
├── src/
│   └── main.rs             # Código principal
├── docker-compose.yml      # Configuração Docker Compose
├── service1/
│   ├── service.json        # Configuração do serviço
│   ├── Dockerfile.service1 # Dockerfile
│   └── config.conf.example # Arquivo de configuração
└── service2/
    ├── service.json
    └── ...
```

### Formato do service.json

```json
{
  "username": "lnd",
  "uid": 1001,
  "groupname": "lnd",
  "gid": 1001,
  "description": "Lightning Network Daemon",
  "data_dir": "/data/lnd",
  "dockerfile": "Dockerfile.lnd",
  "config_files": ["lnd.conf.example", "password.txt"],
  "binaries": ["lnd-linux-amd64-v0.18.5-beta.tar.gz"],
  "ports": ["9735:9735", "10009:10009"],
  "special_dirs": ["logs", "data", "wallets"]
}
```

## Exemplos de Uso

### Exemplo 1: Testar LND isoladamente

```bash
cargo run
# Selecione "Modo de teste individual"
# Escolha "lnd"
# Confirme para incluir dependências (bitcoin)
```

### Exemplo 2: Iniciar stack completa

```bash
cargo run -- --mode auto
# Inicia todos os serviços que têm Dockerfile válido
```

### Exemplo 3: Serviços específicos com dependências

```bash
cargo run -- --services "thunderhub" --deps
# Inicia thunderhub + lnd + bitcoin (dependências)
```

## Vantagens sobre o Script Bash

1. **Type Safety**: Rust previne muitos erros em tempo de compilação
2. **Performance**: Execução mais rápida e eficiente
3. **Error Handling**: Tratamento robusto de erros com stack traces
4. **Concorrência**: Operações assíncronas quando possível
5. **Interface**: Menus interativos mais polidos
6. **Manutenibilidade**: Código mais estruturado e testável
7. **Cross-platform**: Pode ser compilado para diferentes sistemas

## Desenvolvimento

### Adicionar nova funcionalidade

1. Edite `src/main.rs`
2. Adicione dependências no `Cargo.toml` se necessário
3. Teste com `cargo run`
4. Compile release com `cargo build --release`

### Debug

```bash
# Modo verbose
cargo run -- --verbose

# Logs detalhados
RUST_LOG=debug cargo run

# Compile com símbolos de debug
cargo build
```

## Troubleshooting

### Erro: "docker-compose não encontrado"
```bash
# Instalar docker-compose
sudo apt-get install docker-compose
# ou
pip install docker-compose
```

### Erro: "Permissão negada"
```bash
# Verificar se usuário está no grupo docker
sudo usermod -aG docker $USER
# Relogar ou executar:
newgrp docker
```

### Erro de compilação
```bash
# Atualizar Rust
rustup update
# Limpar cache
cargo clean
cargo build
```

## Contributing

1. Fork o projeto
2. Crie uma branch para sua feature
3. Faça commit das mudanças
4. Push para a branch
5. Abra um Pull Request

## License

Este projeto mantém a mesma licença do projeto original.
