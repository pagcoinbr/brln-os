# Manual de Uso - control-systemd.py

## Visão Geral

O `control-systemd.py` é um servidor Flask que fornece uma API REST e WebSocket para monitoramento e controle de containers Docker em tempo real. Desenvolvido especificamente para gerenciar serviços do ecossistema Bitcoin Lightning Network, incluindo LND, Bitcoin Core, Elements, e outras aplicações relacionadas.

## Funcionalidades Principais

### 1. **Gerenciamento de Containers**
- Ligar/desligar containers Docker
- Verificar status em tempo real
- Visualizar logs dos containers
- Monitoramento automático de mudanças de estado

### 2. **Consulta de Saldos**
- Saldo Lightning Network (LND)
- Saldo Bitcoin on-chain
- Saldo Liquid/Elements

### 3. **Operações Lightning**
- Criar invoices
- Pagar invoices
- Consultar informações da wallet

### 4. **Monitoramento em Tempo Real**
- WebSocket para atualizações instantâneas
- Cache inteligente de status
- Monitoramento de sistema (CPU, RAM, etc.)

## Pré-requisitos

### Dependências Python
```bash
pip install -r requirements.txt
```

### Serviços Necessários
- Docker e Docker Compose instalados
- Containers configurados: `lnd`, `bitcoin`, `elements`, `lnbits`, etc.
- Script `status.sh` disponível em `/home/admin/brlnfullauto/container/graphics/cgi-bin/`

## Instalação e Execução

### 1. Instalar Dependências
```bash
cd /home/pagcoin/brlnfullauto/container/graphics
pip install -r requirements.txt
```

### 2. Executar o Servidor
```bash
python control-systemd.py
```

O servidor será iniciado na porta **5001** e estará disponível em: `http://localhost:5001`

## Endpoints da API

### **Gerenciamento de Serviços**

#### `GET /service-status?app=<nome_app>`
Consulta o status de um serviço específico.

**Parâmetros:**
- `app`: Nome do aplicativo (peerswap, lnbits, thunderhub, lnd, bitcoind, etc.)

**Resposta:**
```json
{
  "active": true,
  "status": "running",
  "container": "lnd"
}
```

#### `POST /toggle-service?app=<nome_app>`
Liga ou desliga um serviço.

**Parâmetros:**
- `app`: Nome do aplicativo

**Resposta:**
```json
{
  "success": true,
  "new_status": true,
  "action": "start",
  "container": "lnd"
}
```

#### `GET /containers/status`
Retorna o status de todos os containers mapeados.

**Resposta:**
```json
{
  "lnd": {
    "container": "lnd",
    "running": true,
    "status": "running"
  },
  "bitcoind": {
    "container": "bitcoin",
    "running": true,
    "status": "running"
  }
}
```

### **Logs de Containers**

#### `GET /containers/logs/<container_name>?lines=<numero>`
Recupera os logs de um container.

**Parâmetros:**
- `container_name`: Nome do container
- `lines`: Número de linhas (padrão: 50)

**Resposta:**
```json
{
  "success": true,
  "logs": "2024-01-01 12:00:00 [INF] Starting LND...",
  "container": "lnd"
}
```

### **Consulta de Saldos**

#### `GET /saldo/lightning`
Consulta saldo da Lightning Network.

**Resposta:**
```json
{
  "lightning_balance": "{\n  \"total_balance\": \"1000000\",\n  \"confirmed_balance\": \"1000000\"\n}"
}
```

#### `GET /saldo/onchain`
Consulta saldo Bitcoin on-chain.

**Resposta:**
```json
{
  "onchain_balance": "0.05000000"
}
```

#### `GET /saldo/liquid`
Consulta saldo Liquid/Elements.

**Resposta:**
```json
{
  "liquid_balance": "0.01000000"
}
```

### **Operações Lightning**

#### `POST /lightning/invoice`
Cria uma invoice Lightning.

**Corpo da Requisição:**
```json
{
  "amount": 1000
}
```

**Resposta:**
```json
{
  "invoice": "lnbc10u1p..."
}
```

#### `POST /lightning/pay`
Paga uma invoice Lightning.

**Corpo da Requisição:**
```json
{
  "invoice": "lnbc10u1p..."
}
```

**Resposta:**
```json
{
  "pagamento": "Payment successful"
}
```

### **Sistema**

#### `GET /status_novidade`
Verifica se há atualizações disponíveis.

**Resposta:**
```json
{
  "novidade": true,
  "timestamp": "2024-01-01 12:00:00"
}
```

## WebSocket Events

### **Conexão**
```javascript
const socket = io('http://localhost:5001');
```

### **Eventos Recebidos**

#### `container_status_update`
Atualização de status dos containers.
```javascript
socket.on('container_status_update', (data) => {
  console.log('Status atualizado:', data);
});
```

#### `system_status_update`
Atualização de informações do sistema.
```javascript
socket.on('system_status_update', (data) => {
  console.log('Sistema atualizado:', data);
});
```

#### `balance_update`
Atualização de saldos.
```javascript
socket.on('balance_update', (data) => {
  console.log('Saldos atualizados:', data);
});
```

### **Eventos Enviados**

#### `request_status_update`
Solicita atualização manual do status.
```javascript
socket.emit('request_status_update');
```

#### `request_balance_update`
Solicita atualização de saldo específico.
```javascript
socket.emit('request_balance_update', {type: 'lightning'});
// ou
socket.emit('request_balance_update', {type: 'all'});
```

## Aplicações Suportadas

| Nome App | Container Docker | Descrição |
|----------|------------------|-----------|
| `peerswap` | peerswap | PeerSwap para atomic swaps |
| `lnbits` | lnbits | LNbits wallet interface |
| `thunderhub` | thunderhub | ThunderHub LND manager |
| `lndg` | lndg | LND GUI dashboard |
| `lnd` | lnd | Lightning Network Daemon |
| `bitcoind` | bitcoin | Bitcoin Core |
| `tor` | tor | Tor network |
| `elementsd` | elements | Elements/Liquid |
| `bos-telegram` | bos-telegram | Balance of Satoshis Telegram |

## Exemplo de Uso com JavaScript

```javascript
// Conectar ao WebSocket
const socket = io('http://localhost:5001');

// Verificar status de um serviço
async function checkServiceStatus(app) {
  const response = await fetch(`/service-status?app=${app}`);
  const data = await response.json();
  console.log(`Status do ${app}:`, data);
}

// Alternar serviço
async function toggleService(app) {
  const response = await fetch(`/toggle-service?app=${app}`, {
    method: 'POST'
  });
  const data = await response.json();
  console.log(`Resultado:`, data);
}

// Criar invoice
async function createInvoice(amount) {
  const response = await fetch('/lightning/invoice', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({amount: amount})
  });
  const data = await response.json();
  console.log('Invoice criada:', data);
}

// Escutar atualizações em tempo real
socket.on('container_status_update', (data) => {
  console.log('Containers atualizados:', data);
});

socket.on('balance_update', (data) => {
  console.log('Saldos atualizados:', data);
});
```

## Exemplo de Uso com cURL

```bash
# Verificar status de todos os containers
curl http://localhost:5001/containers/status

# Verificar status do LND
curl "http://localhost:5001/service-status?app=lnd"

# Ligar/desligar o LNbits
curl -X POST "http://localhost:5001/toggle-service?app=lnbits"

# Consultar saldo Lightning
curl http://localhost:5001/saldo/lightning

# Criar invoice de 1000 sats
curl -X POST http://localhost:5001/lightning/invoice \
  -H "Content-Type: application/json" \
  -d '{"amount": 1000}'

# Ver logs do container LND (últimas 100 linhas)
curl "http://localhost:5001/containers/logs/lnd?lines=100"
```

## Monitoramento e Logs

### **Logs do Sistema**
O servidor emite logs no console:
```
[WebSocket] Cliente conectado: abc123
[Sistema] Monitoramento em tempo real iniciado
[WebSocket] Status dos containers atualizado
[WebSocket] Saldos atualizados: ['lightning', 'onchain']
```

### **Frequência de Monitoramento**
- **Containers**: A cada 2 segundos
- **Sistema**: A cada 10 segundos
- **Saldos**: A cada 30 segundos

## Troubleshooting

### **Problemas Comuns**

1. **Container não responde**
   - Verificar se o Docker está rodando
   - Confirmar se o container existe: `docker ps -a`

2. **Comandos CLI falham**
   - Verificar se os containers estão configurados corretamente
   - Confirmar paths dos binários dentro dos containers

3. **WebSocket não conecta**
   - Verificar CORS settings
   - Confirmar se a porta 5001 está acessível

4. **Saldos não atualizam**
   - Verificar se os containers estão rodando
   - Confirmar configurações de RPC

### **Debug**
Para executar em modo debug:
```python
socketio.run(app, host='0.0.0.0', port=5001, debug=True)
```

## Segurança

⚠️ **IMPORTANTE**: Este servidor está configurado para aceitar conexões de qualquer origem (`CORS(app, origins="*")`). Em produção, configure adequadamente as origens permitidas.

## Arquivos Relacionados

- `requirements.txt` - Dependências Python
- `cgi-bin/status.sh` - Script de status do sistema
- `docker-compose.yml` - Configuração dos containers
- Arquivos de configuração específicos de cada serviço

## Suporte

Para suporte adicional, verifique:
1. Logs do sistema no console
2. Status dos containers Docker
3. Configurações de rede e firewall
4. Permissões de arquivo do script `status.sh`
