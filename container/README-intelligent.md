# Sistema Inteligente de Configuração Docker

Este diretório contém um sistema modernizado e inteligente para configuração de serviços Docker Compose, usando arquivos JSON modulares e arrays dinâmicos.

## 🚀 Características Principais

- **Auto-descoberta de serviços**: Detecta automaticamente todos os serviços através de arquivos `service.json`
- **Configuração modular**: Cada serviço tem seu próprio arquivo de configuração
- **Arrays dinâmicos**: Usa laços de repetição para eliminar código duplicado
- **Menu interativo**: Interface amigável para seleção de serviços
- **Validação automática**: Verifica recursos necessários antes da execução
- **Sistema de logs**: Configuração automática de sistema de logs

## 📁 Estrutura de Arquivos

```
container/
├── setup-docker-intelligent.sh    # Script principal (novo sistema)
├── create-new-service.sh          # Criador de novos serviços
├── migrate-to-json.sh             # Migração do sistema antigo
├── users_groups.txt               # Configuração antiga (mantida para compatibilidade)
├── [serviço]/
│   ├── service.json               # Configuração do serviço
│   ├── Dockerfile.[serviço]       # Dockerfile do serviço
│   ├── *.conf.example            # Arquivos de configuração
│   └── entrypoint.sh             # Script de entrada (se necessário)
└── logs/                         # Sistema de logs
```

## 🔧 Como Usar

### 1. Sistema Novo (Recomendado)

```bash
# Executar configuração inteligente
./setup-docker-intelligent.sh
```

O script irá:
- Auto-detectar todos os serviços disponíveis
- Apresentar menu interativo
- Configurar usuários, grupos e permissões automaticamente
- Iniciar os serviços selecionados

### 2. Criar Novo Serviço

```bash
# Criar um novo serviço interativamente
./create-new-service.sh
```

## 📝 Formato do service.json

Cada serviço deve ter um arquivo `service.json` com a seguinte estrutura:

```json
{
    "name": "nome-do-servico",
    "uid": 1000,
    "username": "nome-do-servico",
    "gid": 1000,
    "groupname": "nome-do-servico",
    "data_dir": "/data/nome-do-servico",
    "config_files": [
        "config.conf.example",
        "entrypoint.sh"
    ],
    "special_dirs": [
        "data",
        "logs",
        "subdirectory"
    ],
    "dockerfile": "Dockerfile.nome-do-servico",
    "binaries": [
        "binary-file.tar.gz"
    ],
    "ports": [8080, 9090],
    "description": "Descrição do serviço"
}
```

### Campos Obrigatórios
- `name`: Nome do serviço
- `uid`/`gid`: IDs de usuário e grupo
- `username`/`groupname`: Nomes de usuário e grupo
- `data_dir`: Diretório de dados do serviço
- `description`: Descrição do serviço

### Campos Opcionais
- `config_files`: Lista de arquivos de configuração
- `special_dirs`: Subdiretórios especiais a serem criados
- `dockerfile`: Nome do Dockerfile (padrão: Dockerfile.[name])
- `binaries`: Lista de binários necessários
- `ports`: Portas utilizadas pelo serviço

## 🎯 Opções de Seleção de Serviços

No menu interativo você pode:

1. **Digitar números**: `1 3 5` (seleciona serviços pelas posições)
2. **Digitar nomes**: `lnd elements peerswap` (seleciona por nome)
3. **Selecionar todos**: `all` (configura todos os serviços)
4. **Auto-detecção**: `auto` (seleciona serviços com Dockerfile válido)

## 🔄 Vantagens do Novo Sistema

### Antes (sistema antigo):
- Configuração centralizada em um arquivo
- Código repetitivo para cada serviço
- Difícil de adicionar novos serviços
- Validações manuais

### Depois (sistema novo):
- Configuração modular por serviço
- Arrays dinâmicos e laços de repetição
- Fácil adição de novos serviços
- Auto-validação e auto-descoberta
- Menu interativo
- Sistema de logs integrado

## 📊 Exemplo de Uso

```bash
# 1. Descobrir serviços
./setup-docker-intelligent.sh

# Output:
# Descobertos 7 serviços: lnd elements lnbits peerswap psweb thunderhub tor

# 2. Menu interativo apresentado
# 3. Selecionar serviços: "lnd elements peerswap"
# 4. Sistema configura automaticamente tudo
# 5. Containers iniciados
```

## 🐛 Troubleshooting

### Erro: "jq não encontrado"
```bash
sudo apt-get update && sudo apt-get install -y jq
```

### Erro: "Arquivo service.json inválido"
```bash
# Validar JSON
jq empty serviço/service.json

# Recriar usando o criador
./create-new-service.sh
```

### Serviço não detectado
1. Verificar se existe `service.json` no diretório do serviço
2. Validar formato JSON
3. Verificar se todos os campos obrigatórios estão presentes

## 🔧 Manutenção

### Adicionar novo serviço:
1. `./create-new-service.sh` (método recomendado)
2. Ou criar manualmente diretório + `service.json`

### Modificar serviço existente:
1. Editar `serviço/service.json`
2. Executar `./setup-docker-intelligent.sh`

### Backup de configurações:
```bash
# Backup de todos os service.json
tar -czf backup-services-$(date +%Y%m%d).tar.gz */service.json
```

## 📈 Logs e Monitoramento

O sistema inclui configuração automática de logs:
- Logs centralizados em `container/logs/`
- Sistema de rotação automática
- Integração com docker-compose logs

```bash
# Ver logs de um serviço específico
docker-compose logs -f lnd

# Ver logs do sistema
tail -f container/logs/stdout.log
```

## 🤝 Contribuindo

Para adicionar novos serviços ao sistema:
1. Use `./create-new-service.sh`
2. Configure adequadamente o `service.json`
3. Teste com `./setup-docker-intelligent.sh`
4. Documente peculiaridades no README do serviço
