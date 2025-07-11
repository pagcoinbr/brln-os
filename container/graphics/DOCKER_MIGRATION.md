# Migração do Sistema de Controle: SystemD para Docker

## Resumo das Alterações

O sistema de controle foi migrado de **systemd services** para **Docker containers**, permitindo que a interface gráfica continue funcionando com os botões switch, mas agora controlando containers Docker em vez de serviços do sistema.

## Principais Mudanças

### 1. Arquivo: `control-systemd.py`

**Antes:**
- Controlava serviços systemd usando `systemctl`
- Mapeamento para `.service` files

**Depois:**
- Controla containers Docker usando comandos `docker`
- Mapeamento para nomes de containers
- Suporte a `docker-compose` como fallback

### 2. Mapeamento de Serviços → Containers

```python
APP_TO_CONTAINER = {
    "peerswap": "peerswap",
    "lnbits": "lnbits", 
    "thunderhub": "thunderhub",
    "simple": "simple-lnwallet",
    "lndg": "lndg",
    "lndg-controller": "lndg",  # Mesmo container que lndg
    "lnd": "lnd",
    "bitcoind": "bitcoin",      # Container name diferente do app name
    "tor": "tor",
    "elementsd": "elements",    # Container name diferente do app name
    "bos-telegram": "bos-telegram",
}
```

### 3. Novas Funcionalidades

#### Rotas de Status Melhoradas
- `/service-status?app=<name>` - Status individual do container
- `/containers/status` - Status de todos os containers
- `/containers/logs/<container_name>` - Logs em tempo real

#### Integração com CLI via Docker
- `/saldo/lightning` - Executa `lncli` dentro do container LND
- `/saldo/onchain` - Executa `bitcoin-cli` dentro do container Bitcoin  
- `/saldo/liquid` - Executa `elements-cli` dentro do container Elements

### 4. Script de Status Atualizado

O arquivo `cgi-bin/status.sh` foi atualizado para usar comandos Docker:

```bash
# Função para verificar status de container Docker
check_container() {
    local container_name="$1"
    if docker inspect "$container_name" &>/dev/null; then
        if docker inspect -f '{{.State.Running}}' "$container_name" | grep -q true; then
            echo "ativo"
        else
            echo "parado" 
        fi
    else
        echo "inexistente"
    fi
}
```

## Como Funciona

### Detecção de Status
1. Usa `docker inspect` para verificar se container existe
2. Verifica se `State.Running` é `true`
3. Retorna status detalhado: "running", "stopped", "not_found", etc.

### Controle de Containers
1. **Start**: Tenta `docker start <container>`, se falhar usa `docker-compose up -d <container>`
2. **Stop**: Usa `docker stop <container>`
3. **Fallback**: Em caso de erro no `docker start`, tenta o docker-compose

### Execução de Comandos
- Comandos CLI agora são executados **dentro** dos containers usando `docker exec`
- Exemplo: `docker exec lnd lncli walletbalance`

## Vantagens da Nova Abordagem

1. **Isolamento**: Cada serviço roda em seu próprio container
2. **Portabilidade**: Facilita deploy em diferentes ambientes
3. **Gerenciamento**: Docker-compose permite controle orquestrado
4. **Logs**: Acesso fácil aos logs de cada container
5. **Debugging**: Containers podem ser inspecionados individualmente

## Interface Gráfica

### Botões Switch
Os botões switch na interface `main.html` continuam funcionando exatamente igual:
- ✅ Mesmas funções JavaScript (`toggleService`)
- ✅ Mesma API (`/service-status`, `/toggle-service`)
- ✅ Mesmo comportamento visual

### Monitoramento
O painel de status continua mostrando:
- CPU e RAM do sistema host
- Status de cada container (ativo/parado/inexistente)
- Configuração de blockchain (local/remoto)

## Comandos Úteis

### Ver status de todos os containers:
```bash
curl http://localhost:5001/containers/status
```

### Ver logs de um container:
```bash
curl http://localhost:5001/containers/logs/lnd?lines=20
```

### Controlar container via API:
```bash
# Parar container
curl -X POST http://localhost:5001/toggle-service?app=lnd

# Ver status
curl http://localhost:5001/service-status?app=lnd
```

## Troubleshooting

### Container não inicia
1. Verifique se o container existe: `docker ps -a`
2. Tente iniciar manualmente: `docker start <container>`
3. Se falhar, use docker-compose: `docker-compose up -d <container>`

### API não responde
1. Verifique se o Flask está rodando na porta 5001
2. Confirme que o Docker está instalado e funcionando
3. Verifique permissões para executar comandos Docker

### Interface não atualiza status
1. Verifique se o script `status.sh` tem permissões de execução
2. Teste o script diretamente: `bash /path/to/status.sh`
3. Confirme que os containers têm os nomes corretos

## Dependências

- **Docker Engine**: Para controlar containers
- **Docker Compose**: Para orquestração (opcional)
- **Flask**: Para API web
- **Bash**: Para script de status
