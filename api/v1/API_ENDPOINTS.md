# BRLN-OS API v1 - Endpoints

Esta API foi reorganizada por categorias funcionais para melhor organização e usabilidade.

## System Management (Gerenciamento do Sistema)

### GET /api/v1/system/status
Retorna status completo do sistema incluindo CPU, RAM, LND, Bitcoin e blockchain.

**Response:**
```json
{
  "cpu": {"usage": 25.5, "load": "0.8, 0.9, 1.0"},
  "ram": {"used": "2.1GB", "total": "8.0GB", "percentage": 26.2},
  "lnd": {...},
  "bitcoind": {...},
  "tor": {"status": "running"},
  "blockchain": {"size": "450GB", "progress": 100}
}
```

### GET /api/v1/system/services
Retorna status de todos os serviços do sistema.

### POST /api/v1/system/service
Gerencia serviços (start/stop/restart).

**Request:**
```json
{
  "service": "lnd",
  "action": "restart"
}
```

### GET /api/v1/system/health
Health check simples.

## Wallet Management (Gerenciamento da Carteira On-chain)

### GET /api/v1/wallet/balance/onchain
Retorna saldo Bitcoin on-chain.

### GET /api/v1/wallet/transactions
Lista transações on-chain com filtros opcionais.

**Query Parameters:**
- `start_height` (int): Altura inicial do bloco
- `end_height` (int): Altura final do bloco
- `account` (string): Nome da conta

### POST /api/v1/wallet/transactions/send
Envia Bitcoin on-chain.

**Request:**
```json
{
  "addr": "bc1q...",
  "amount": 100000,
  "send_all": false,
  "sat_per_vbyte": 10,
  "label": "Pagamento teste"
}
```

### POST /api/v1/wallet/addresses
Gera novo endereço Bitcoin.

**Request:**
```json
{
  "type": "p2wkh",
  "account": "default"
}
```

### GET /api/v1/wallet/utxos
Lista UTXOs disponíveis.

**Query Parameters:**
- `min_confs` (int): Confirmações mínimas
- `max_confs` (int): Confirmações máximas
- `account` (string): Nome da conta

## Lightning Network

### GET /api/v1/lightning/peers
Lista peers Lightning conectados.

### POST /api/v1/lightning/peers/connect
Conecta a um peer Lightning.

**Request:**
```json
{
  "lightning_address": "pubkey@host:port",
  "perm": true,
  "timeout": 60
}
```

### GET /api/v1/lightning/channels
Lista canais Lightning ativos.

### POST /api/v1/lightning/channels/open
Abre um novo canal Lightning.

**Request:**
```json
{
  "node_pubkey": "03abc...",
  "local_funding_amount": 1000000,
  "private": false,
  "push_sat": 0,
  "sat_per_vbyte": 5
}
```

### POST /api/v1/lightning/channels/close
Fecha um canal Lightning.

**Request:**
```json
{
  "channel_point": "txid:index",
  "force_close": false,
  "sat_per_vbyte": 10
}
```

### GET /api/v1/lightning/channels/pending
Lista canais Lightning pendentes.

### POST /api/v1/lightning/invoices
Cria uma invoice Lightning.

**Request:**
```json
{
  "memo": "Descrição da invoice",
  "value": 21000,
  "expiry": 3600,
  "private": false
}
```

### POST /api/v1/lightning/payments
Envia pagamento Lightning.

**Request:**
```json
{
  "payment_request": "lnbc...",
  "fee_limit_sat": 100,
  "timeout_seconds": 60
}
```

### POST /api/v1/lightning/payments/keysend
Envia keysend (pagamento espontâneo).

**Request:**
```json
{
  "dest": "03abc...",
  "amt": 21000,
  "fee_limit_sat": 100,
  "custom_records": {}
}
```

## Migração de Rotas Antigas

| Rota Antiga | Nova Rota | Categoria |
|-------------|-----------|-----------|
| `/api/v1/config/system-status` | `/api/v1/system/status` | System |
| `/api/v1/config/services-status` | `/api/v1/system/services` | System |
| `/api/v1/config/service` | `/api/v1/system/service` | System |
| `/api/v1/config/health` | `/api/v1/system/health` | System |
| `/api/v1/balance/blockchain` | `/api/v1/wallet/balance/onchain` | Wallet |
| `/api/v1/transactions` | `/api/v1/wallet/transactions` | Wallet |
| `/api/v1/transactions/send` | `/api/v1/wallet/transactions/send` | Wallet |
| `/api/v1/addresses` | `/api/v1/wallet/addresses` | Wallet |
| `/api/v1/utxos` | `/api/v1/wallet/utxos` | Wallet |
| `/api/v1/peers` | `/api/v1/lightning/peers` | Lightning |
| `/api/v1/peers/connect` | `/api/v1/lightning/peers/connect` | Lightning |
| `/api/v1/channels` | `/api/v1/lightning/channels` | Lightning |
| `/api/v1/channels/*` | `/api/v1/lightning/channels/*` | Lightning |
| `/api/v1/invoices` | `/api/v1/lightning/invoices` | Lightning |
| `/api/v1/payments` | `/api/v1/lightning/payments` | Lightning |
| `/api/v1/payments/keysend` | `/api/v1/lightning/payments/keysend` | Lightning |

## Benefícios da Reorganização

1. **Organização lógica**: Endpoints agrupados por funcionalidade
2. **Fácil navegação**: Estrutura hierárquica clara
3. **Manutenibilidade**: Mais fácil adicionar novos endpoints
4. **Documentação**: Estrutura autodocumentada
5. **Separação de responsabilidades**: Cada categoria tem propósito específico

## Versioning

Esta é a versão 1 da API. Futuras versões manterão compatibilidade com a estrutura reorganizada.