# BRLN-OS: Arquitetura Técnica Completa

## Sistema Operacional para Auto-Custódia Bitcoin com Atomic Swaps Descentralizados

**Versão:** 2.0
**Data:** Janeiro 2026
**Status:** 40% Implementado (Database + LND + HTLC ready)
**Autor:** Comunidade BRLN
**Licença:** MIT

---

## Índice

1. [Visão Geral do Sistema](#1-visão-geral-do-sistema)
2. [Arquitetura em Camadas](#2-arquitetura-em-camadas)
3. [Super Wallet: Integração LND + Elements](#3-super-wallet-integração-lnd--elements)
4. [Atomic Swaps: Fundamentos Técnicos](#4-atomic-swaps-fundamentos-técnicos)
5. [Rede P2P: Descoberta e Coordenação](#5-rede-p2p-descoberta-e-coordenação)
6. [Database: Persistência e Gerenciamento](#6-database-persistência-e-gerenciamento)
7. [Integrações Externas](#7-integrações-externas)
8. [Stack Tecnológica](#8-stack-tecnológica)
9. [Fluxos Completos End-to-End](#9-fluxos-completos-end-to-end)
10. [Segurança](#10-segurança)
11. [Deployment e Operação](#11-deployment-e-operação)
12. [Roadmap e Futuro](#12-roadmap-e-futuro)
13. [Apêndices](#13-apêndices)

---

# 1. Visão Geral do Sistema

## 1.1 O que é BRLN-OS

**BRLN-OS** (Bitcoin Open Bank) é uma distribuição completa que transforma qualquer servidor Ubuntu 24.04 LTS em um **nó soberano multi-funcional** de Bitcoin + Lightning Network + Liquid Network, com foco em:

- **Auto-Custódia Total**: Você controla suas chaves privadas e seus fundos
- **Privacidade Como Direito**: Transações e saldos protegidos por Tor e I2P
- **Soberania Digital**: Software livre rodando no seu hardware
- **Resistência à Vigilância**: Sem dependências de serviços terceirizados
- **Atomic Swaps Descentralizados**: Troca de ativos sem intermediários (em desenvolvimento)

O BRLN-OS não é apenas um "instalador de Bitcoin Core". É um **sistema operacional completo** que:

1. **Instala e configura** automaticamente: Bitcoin Core, LND, Elements/Liquid
2. **Integra** múltiplas aplicações Lightning (ThunderHub, LNbits, LNDg, BOS)
3. **Expõe** API REST unificada (Flask + gRPC) para controle programático
4. **Fornece** interface web em português para operação sem linha de comando
5. **Gerencia** serviços via systemd com resiliência e auto-restart
6. **Implementa** atomic swaps entre Lightning, Bitcoin e Liquid (MVP em desenvolvimento)

### Filosofia do Projeto

O BRLN-OS é construído sobre princípios fundamentais:

**Privacidade Como um Direito**
Suas transações e saldos devem ser controlados por você, rodando na sua própria infraestrutura, sem custódia de terceiros. Com grandes poderes, vêm grandes responsabilidades.

**Soberania Digital**
O nó roda no seu hardware, com software livre (MIT License) e serviços auto-hospedados. Você não depende de ninguém para operar.

**Resistência à Vigilância**
Uso de Tor, suporte a I2P (i2pd) e VPN opcional (Tailscale) para reduzir exposição de rede em qualquer lugar do mundo.

**Empoderamento Individual**
Interface em português, menus interativos (TUI) e automação para reduzir a barreira técnica de operar um nó completo de Bitcoin.

A principal motivação é **proteger a privacidade e a liberdade** das pessoas, especialmente em contextos onde a vigilância e o controle financeiro podem colocar vidas em risco.

## 1.2 Casos de Uso

### Nó Pessoal Soberano (Indivíduo)

**Cenário:** João quer total controle sobre seus Bitcoins sem confiar em exchanges.

**Solução BRLN-OS:**
- Roda Bitcoin Core completo validando toda a blockchain
- LND para pagamentos Lightning instantâneos
- Liquid para transações confidenciais
- Backup automático de canais (SCB)
- Interface web para operação diária

**Benefícios:**
- Zero confiança em terceiros
- Privacidade máxima (Tor + VPN)
- Controle total das chaves privadas
- Pagamentos Lightning sem custódia

### Roteador Lightning Comercial (Merchant)

**Cenário:** Maria tem uma loja online e quer aceitar Bitcoin via Lightning.

**Solução BRLN-OS:**
- LNbits para criar múltiplas sub-carteiras por departamento
- ThunderHub para monitorar canais em tempo real
- Balance of Satoshis para rebalanceamento automático
- API REST para integração com e-commerce
- PeerSwap para liquidez via Liquid

**Benefícios:**
- Recebimento instantâneo (Lightning)
- Taxas baixas (~1 satoshi por pagamento)
- Liquidez gerenciada automaticamente
- Accounting por departamento (LNbits)

### Provedor de Liquidez (Swap Operator)

**Cenário:** Carlos quer fornecer liquidez para atomic swaps e ganhar fees.

**Solução BRLN-OS:**
- Atomic swap engine (L-BTC ↔ Lightning)
- Database de peers com sistema de reputação
- Monitoramento automático de HTLCs
- Recovery files para segurança
- API REST para anúncio de liquidez

**Benefícios:**
- Fees por swap (~0.1-0.5%)
- Operação automatizada 24/7
- Risco mitigado (HTLCs + timeouts)
- Integração com rede P2P

### Exchange Peer-to-Peer (P2P Platform)

**Cenário:** Ana quer criar plataforma de trocas descentralizadas.

**Solução BRLN-OS:**
- Backend de atomic swaps pronto
- API REST para integração frontend
- Gossip protocol para descoberta de peers
- Sistema de reputação integrado
- Múltiplos tipos de swap (BTC, Lightning, L-BTC)

**Benefícios:**
- Sem custódia de fundos dos usuários
- Totalmente trustless (HTLC)
- Escalável via rede P2P
- Código aberto (MIT)

## 1.3 Conceitos Fundamentais

Antes de mergulhar na arquitetura técnica, é importante entender os conceitos-chave que o BRLN-OS unifica:

### Auto-Custódia vs Custódia Terceirizada

| Característica | Auto-Custódia (BRLN-OS) | Custódia Terceirizada (Exchange) |
|---------------|-------------------------|----------------------------------|
| **Controle das chaves** | Você | Exchange |
| **Risco de perda** | Falha de hardware/backup | Hack da exchange, falência |
| **Privacidade** | Total (Tor/VPN) | Zero (KYC, vigilância) |
| **Responsabilidade** | Sua | Terceiros |
| **Resistência à censura** | Absoluta | Nenhuma |

**Princípio:** "Not your keys, not your coins" (Sem suas chaves, não são suas moedas)

### Lightning Network

**O que é:** Segunda camada (Layer 2) sobre Bitcoin para pagamentos instantâneos.

**Como funciona:**
1. Abre canal pagando transação on-chain (lento, caro)
2. Faz milhares de pagamentos off-chain (instantâneo, barato)
3. Fecha canal quando quiser (uma transação on-chain)

**Vantagens:**
- Pagamentos em segundos
- Taxas de ~1 satoshi
- Escalabilidade (milhões de TPS teórico)

**Desvantagens:**
- Requer liquidez em canais
- Complexidade de roteamento
- Necessita node online

**Uso no BRLN-OS:** LND como daemon, ThunderHub/LNbits como interfaces, atomic swaps para gerenciar liquidez.

### Liquid Network

**O que é:** Sidechain (cadeia lateral) de Bitcoin focada em privacidade e rapidez.

**Características:**
- Blocos de **1 minuto** (vs 10 min do Bitcoin)
- Transações **confidenciais** (valores e assets ocultos)
- Suporte a **múltiplos ativos** (L-BTC, USDT, stablecoins)
- Federação de exchanges e custodiantes

**L-BTC:** Bitcoin "ancorado" (pegged) na Liquid. 1 L-BTC = 1 BTC.

**Uso no BRLN-OS:** Elements daemon, atomic swaps L-BTC ↔ Lightning, transações confidenciais.

### Atomic Swaps

**O que são:** Trocas de ativos entre duas partes **sem intermediário**, com garantia matemática de que a troca é:

- **Atômica:** Ou completa 100% ou não acontece nada
- **Trustless:** Nenhuma parte precisa confiar na outra
- **Descentralizada:** Sem custódio central
- **Segura:** Garantias criptográficas (HTLC)

**Tecnologia:** Hash Time Lock Contracts (HTLC)
- Hash Lock: Preimage secreto revela quando pagar
- Time Lock: Timeout para reembolso se swap não completar

**Exemplo:**
- Alice tem L-BTC, quer Lightning
- Bob tem Lightning, quer L-BTC
- Swap atômico: Alice envia L-BTC, recebe Lightning (ou nada acontece)

**Uso no BRLN-OS:** Core engine implementado, API REST para iniciar swaps, rede P2P para descoberta de peers (planejado).

## 1.4 Diagrama: Visão 360° do Ecossistema

```
┌─────────────────────────────────────────────────────────────────┐
│                       USUÁRIO FINAL                             │
│           (Browser HTTPS - Apache 443)                          │
│    Acesso via VPN (Tailscale) ou Tor Hidden Service            │
└─────────────────────┬───────────────────────────────────────────┘
                      │ HTTPS
           ┌──────────▼──────────┐
           │   Apache 2.4        │
           │   Reverse Proxy     │
           │   SSL/TLS           │
           └──────────┬──────────┘
                      │
           ┌──────────▼──────────┐
           │   Frontend Pages    │
           │   (HTML/CSS/JS)     │
           │   /var/www/html     │
           │                     │
           │   - home/           │ Dashboard de status
           │   - bitcoin/        │ On-chain Bitcoin
           │   - lightning/      │ Lightning canais
           │   - elements/       │ Liquid assets
           │   - wallet/         │ HD wallet manager
           │   - config/         │ Configurações sistema
           └──────────┬──────────┘
                      │ fetch() API
           ┌──────────▼──────────┐
           │   BRLN API (Flask)  │
           │   Port 2121 (HTTP)  │
           │   ~115 endpoints    │
           │                     │
           │   /api/v1/system    │ Health, CPU, RAM
           │   /api/v1/wallet    │ HD wallet, seeds
           │   /api/v1/lightning │ LND operations
           │   /api/v1/bitcoin   │ Bitcoin RPC proxy
           │   /api/v1/elements  │ Liquid operations
           │   /api/v1/swaps     │ Atomic swaps (NEW)
           └──────────┬──────────┘
                      │
    ┌─────────────────┼─────────────────────────┐
    │                 │                         │
┌───▼────┐    ┌──────▼──────┐    ┌────────▼────────┐
│ LND    │    │ Bitcoin     │    │ Elements        │
│ gRPC   │    │ Core RPC    │    │ (Liquid) RPC    │
│ :10009 │    │ :8332       │    │ :7041           │
└───┬────┘    └──────┬──────┘    └────────┬────────┘
    │                │                     │
    │         ┌──────▼─────────────────────▼─────┐
    │         │   Blockchain Networks            │
    │         │   - Bitcoin Mainnet              │
    │         │   - Lightning Network            │
    │         │   - Liquid Sidechain             │
    │         └──────────────────────────────────┘
    │
    └─────────────────────────────────┐
                                      │
                            ┌─────────▼──────────┐
                            │  Database          │
                            │  (PostgreSQL/      │
                            │   SQLite)          │
                            │                    │
                            │  - swaps           │
                            │  - peers           │
                            │  - swap_txs        │
                            │  - swap_events     │
                            └────────────────────┘
```

**Fluxo de Dados:**
1. **Usuário** acessa interface via HTTPS (VPN/Tor)
2. **Apache** serve frontend estático e faz proxy reverso para API
3. **Frontend** faz requisições AJAX (fetch) para API Flask
4. **API Flask** comunica via gRPC (LND) e JSON-RPC (Bitcoin, Elements)
5. **Daemons** executam operações e retornam resultados
6. **Database** persiste swaps, peers, eventos

---

# 2. Arquitetura em Camadas

O BRLN-OS é estruturado em **três camadas principais** que se comunicam de forma hierárquica e bem definida.

## 2.1 Camada 1: Daemons (Infraestrutura Base)

Esta é a camada mais baixa, responsável por toda a interação com as blockchains. Três daemons principais rodam como serviços systemd dedicados.

### Bitcoin Core 29.2

**Função:** Validação completa da blockchain Bitcoin, gerenciamento de UTXOs, broadcast de transações.

**Configuração:** `/root/brln-os/conf_files/bitcoin.conf`

**Destaques da Configuração:**
```bash
# Privacidade
onlynet=onion          # Apenas Tor (pode adicionar i2p)
proxy=127.0.0.1:9050   # Tor SOCKS5
bind=127.0.0.1         # Não aceita conexões externas

# Performance
dbcache=4000           # 4GB de cache (ajustar conforme RAM)
maxconnections=40      # Limita peers

# Pruning (opcional)
prune=50000            # Reduz storage para ~50GB
# Comente para node full (600GB+)

# ZMQ para notificações em tempo real
zmqpubrawblock=tcp://127.0.0.1:28332
zmqpubrawtx=tcp://127.0.0.1:28333

# RPC
rpcuser=bitcoin        # Gerenciado via SecurePasswordAPI
rpcpassword=***ENCRYPTED***
rpcbind=127.0.0.1
rpcport=8332
```

**Portas:**
- **8332:** RPC (mainnet)
- **18332:** RPC (testnet)
- **8333:** P2P (mainnet)
- **18333:** P2P (testnet)

**Arquivos de Dados:**
- Datadir: `/home/bitcoin/.bitcoin` (mainnet) ou `/home/bitcoin/.bitcoin/testnet3` (testnet)
- Size: ~600GB (mainnet full), ~50GB (pruned), ~30GB (testnet)

**Integração BRLN:**
- API Flask faz JSON-RPC calls para `http://localhost:8332`
- Autenticação via SecurePasswordAPI
- Endpoints: `getblockchaininfo`, `getbalance`, `sendrawtransaction`, `estimatesmartfee`

**Script de Instalação:** `/root/brln-os/scripts/bitcoin.sh`

---

### LND 0.20.0 (Lightning Network Daemon)

**Função:** Nó Lightning Network, gerenciamento de canais, invoices, pagamentos, roteamento.

**Configuração:** `/root/brln-os/conf_files/lnd.conf`

**Destaques da Configuração:**
```bash
[Application Options]
alias=BRLN-Node-$(hostname)
listen=localhost
maxpendingchannels=5
minchansize=20000        # 20k sats mínimo por canal
accept-keysend=true      # Para chat Lightning
accept-amp=true          # Atomic Multi-Path

[Bitcoin]
bitcoin.active=true
bitcoin.mainnet=true     # ou bitcoin.testnet=true
bitcoin.node=bitcoind

[Bitcoind]
bitcoind.rpchost=localhost:8332
bitcoind.rpcuser=bitcoin
bitcoind.rpcpass=***ENCRYPTED***
bitcoind.zmqpubrawblock=tcp://127.0.0.1:28332
bitcoind.zmqpubrawtx=tcp://127.0.0.1:28333

[tor]
tor.active=true
tor.socks=127.0.0.1:9050
tor.control=127.0.0.1:9051
tor.v3=true

[autopilot]
autopilot.active=false   # Recomendamos gestão manual

[wtclient]
wtclient.active=true     # Watchtower client para segurança

[protocol]
protocol.wumbo-channels=true  # Canais >0.16 BTC
```

**Portas:**
- **10009:** gRPC (API principal)
- **9735:** P2P Lightning
- **8080:** REST API (opcional)

**Arquivos de Dados:**
- Datadir: `/home/lnd/.lnd`
- Macaroon: `/home/lnd/.lnd/data/chain/bitcoin/mainnet/admin.macaroon`
- TLS Cert: `/home/lnd/.lnd/tls.cert`
- SCB Backup: `/home/lnd/.lnd/data/chain/bitcoin/mainnet/channel.backup`

**Integração BRLN:**
- API Flask usa gRPC client (`LNDgRPCClient`) com TLS + Macaroon auth
- Stubs gRPC gerados de protos em `/root/brln-os/api/v1/proto/`
- Operações: `ListChannels`, `OpenChannel`, `SendPayment`, `AddInvoice`, `SubscribeInvoices`

**Aplicações LND Integradas:**
1. **ThunderHub** (Node.js) - Dashboard web moderno
2. **LNbits** (Python) - Banking layer, sub-carteiras
3. **LNDg** (Django) - Dashboard avançado, analytics
4. **Balance of Satoshis (BOS)** (Node.js) - CLI avançada, Telegram bot
5. **Simple LNWallet** (Go) - Carteira minimalista

**Script de Instalação:** `/root/brln-os/scripts/lightning.sh`

---

### Elements/Liquid Daemon 24.0

**Função:** Nó Liquid sidechain, transações confidenciais, múltiplos ativos (L-BTC, USDT, etc).

**Configuração:** `/root/brln-os/conf_files/elements.conf`

**Destaques da Configuração:**
```bash
# Network
chain=liquidv1
listen=1
bind=127.0.0.1

# RPC
rpcuser=elements
rpcpassword=***ENCRYPTED***
rpcbind=127.0.0.1
rpcport=7041
rpcallowip=127.0.0.1

# Proxy Tor
proxy=127.0.0.1:9050
onlynet=onion

# Validate pegins (opcional)
# Requer Bitcoin Core RPC
validatepegin=1
mainchainrpchost=127.0.0.1
mainchainrpcport=8332
mainchainrpcuser=bitcoin
mainchainrpcpassword=***ENCRYPTED***

# Assets conhecidos
# L-BTC: 6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d
# USDT: ce091c998b83c78bb71a632313ba3760f1763d9cfcffae02258ffa9865a37bd2
```

**Portas:**
- **7041:** RPC (mainnet)
- **7042:** P2P
- **18891:** RPC (testnet)

**Arquivos de Dados:**
- Datadir: `/home/elements/.elements`
- Size: ~30GB (Liquid mainnet), ~5GB (testnet)
- Wallet: Criada automaticamente (`peerswap` wallet usada por padrão)

**Integração BRLN:**
- API Flask usa `ElementsRPCClient` (JSON-RPC HTTP)
- Autenticação: Basic Auth com SecurePasswordAPI
- Operações: `getbalances`, `sendtoaddress`, `listunspent`, `createrawtransaction`

**Assets Suportados:**
- **L-BTC:** Bitcoin na Liquid (1:1 peg)
- **DePix:** Asset brasileiro
- **USDT:** Tether na Liquid
- **Issued Assets:** Qualquer asset emitido

**Script de Instalação:** `/root/brln-os/scripts/elements.sh`

---

### Diagrama: Comunicação Entre Daemons

```
┌──────────────────────────────────────────────────────────┐
│          API Flask (Python)                              │
│          /root/brln-os/api/v1/app.py                     │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ LND gRPC     │  │ Bitcoin RPC  │  │ Elements RPC │  │
│  │ Client       │  │ Client       │  │ Client       │  │
│  │              │  │              │  │              │  │
│  │ - TLS Cert   │  │ - JSON-RPC   │  │ - JSON-RPC   │  │
│  │ - Macaroon   │  │ - Basic Auth │  │ - Basic Auth │  │
│  │   Auth       │  │              │  │              │  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │
└─────────┼──────────────────┼──────────────────┼──────────┘
          │                  │                  │
     gRPC │             JSON-RPC            JSON-RPC
    :10009│             :8332               :7041
          │                  │                  │
   ┌──────▼──────┐    ┌──────▼──────┐   ┌──────▼──────┐
   │    LND      │    │  bitcoind   │   │  elementsd  │
   │   Daemon    │    │   Daemon    │   │   Daemon    │
   │             │    │             │   │             │
   │ - Lightning │    │ - Bitcoin   │   │ - Liquid    │
   │   Network   │    │   Core      │   │   Sidechain │
   │ - Channels  │    │ - UTXOs     │   │ - L-BTC     │
   │ - Invoices  │    │ - Mempool   │   │ - Assets    │
   │ - Routing   │    │ - Blocks    │   │ - Confid.   │
   └──────┬──────┘    └──────┬──────┘   └──────┬──────┘
          │                  │                  │
          │                  │                  │
          └──────────────────┴──────────────────┘
                             │
                  ┌──────────▼──────────┐
                  │   Blockchain        │
                  │   Networks          │
                  │                     │
                  │ - Bitcoin (P2P)     │
                  │ - Lightning (P2P)   │
                  │ - Liquid (P2P)      │
                  └─────────────────────┘
```

**Observações Importantes:**

1. **Todos os daemons** rodam como usuários dedicados (bitcoin, lnd, elements)
2. **Comunicação local** apenas (127.0.0.1), sem exposição externa
3. **Tor** usado para P2P de todos os daemons
4. **Credenciais** gerenciadas via SecurePasswordAPI (criptografadas com master password)
5. **systemd** gerencia ciclo de vida (start, stop, restart, auto-restart em crash)

---

## 2.2 Camada 2: API Backend (Flask + gRPC Bridge)

A API BRLN é o **cérebro** do sistema, fazendo a ponte entre o frontend (interface do usuário) e os daemons (Bitcoin, LND, Elements).

### Estrutura da API

**Arquivo Principal:** `/root/brln-os/api/v1/app.py` (7583 linhas, ~115 endpoints)

**Tecnologias:**
- **Flask 3.0:** Framework web Python
- **grpcio 1.60:** Cliente gRPC para LND
- **requests:** Cliente HTTP para Bitcoin/Elements RPC
- **SQLAlchemy 2.0:** ORM para database de swaps
- **Fernet/PBKDF2:** Criptografia de seeds e preimages

### Grupos de Endpoints

#### 1. System Management (`/api/v1/system/*`)

**Função:** Status de serviços, monitoramento de recursos, health checks.

**Endpoints:**
```python
GET  /api/v1/system/health
GET  /api/v1/system/status
GET  /api/v1/system/services
POST /api/v1/system/service
GET  /api/v1/system/cpu
GET  /api/v1/system/ram
GET  /api/v1/system/disk
```

**Exemplo - Health Check:**
```bash
curl http://localhost:2121/api/v1/system/health

# Response:
{
  "status": "healthy",
  "services": {
    "bitcoind": "active",
    "lnd": "active",
    "elementsd": "active",
    "brln-api": "active"
  },
  "timestamp": "2026-01-15T10:30:00Z"
}
```

#### 2. HD Wallet Management (`/api/v1/wallet/*`)

**Função:** Geração/importação de seeds BIP39, derivação de chaves (Bitcoin, Ethereum, TRON, Liquid).

**Endpoints:**
```python
POST /api/v1/wallet/generate        # Gerar novo seed BIP39
POST /api/v1/wallet/import          # Importar seed existente
POST /api/v1/wallet/save            # Salvar wallet criptografado
GET  /api/v1/wallet/list            # Listar wallets salvas
POST /api/v1/wallet/load            # Carregar wallet específica
POST /api/v1/wallet/integrate       # Integrar com LND/Elements
GET  /api/v1/wallet/balance/onchain # Saldo Bitcoin on-chain
GET  /api/v1/wallet/balance/lightning # Saldo Lightning
GET  /api/v1/wallet/transactions    # Histórico de transações
POST /api/v1/wallet/transactions/send # Enviar Bitcoin
POST /api/v1/wallet/addresses       # Gerar endereço novo
```

**Exemplo - Gerar Wallet:**
```bash
curl -X POST http://localhost:2121/api/v1/wallet/generate \
  -H "Content-Type: application/json" \
  -d '{"strength": 256}'

# Response:
{
  "mnemonic": "abandon abandon abandon ... art",
  "addresses": {
    "bitcoin": "bc1q...",
    "ethereum": "0x...",
    "tron": "T...",
    "liquid": "ex1q..."
  },
  "warning": "SAVE THIS MNEMONIC SECURELY! It will NEVER be shown again."
}
```

#### 3. Lightning Network (`/api/v1/lightning/*`)

**Função:** Gerenciamento completo de LND (canais, peers, invoices, pagamentos).

**Endpoints:**
```python
GET  /api/v1/lightning/peers
POST /api/v1/lightning/peers/connect
GET  /api/v1/lightning/channels
POST /api/v1/lightning/channels/open
POST /api/v1/lightning/channels/close
GET  /api/v1/lightning/channels/pending
POST /api/v1/lightning/invoices
GET  /api/v1/lightning/invoices/{payment_hash}
POST /api/v1/lightning/payments
POST /api/v1/lightning/payments/keysend
GET  /api/v1/lightning/chat/conversations
POST /api/v1/lightning/chat/send
```

**Exemplo - Criar Invoice:**
```bash
curl -X POST http://localhost:2121/api/v1/lightning/invoices \
  -H "Content-Type: application/json" \
  -H "Cookie: session_id=abc123" \
  -d '{
    "amount_sat": 100000,
    "memo": "Payment for service",
    "expiry": 3600
  }'

# Response:
{
  "payment_request": "lnbc1m1...",
  "payment_hash": "7f3e9a...",
  "expires_at": "2026-01-15T11:30:00Z"
}
```

#### 4. Bitcoin On-Chain (`/api/v1/bitcoin/*`)

**Função:** Proxy para Bitcoin Core RPC, fee estimation, block queries.

**Endpoints:**
```python
GET  /api/v1/bitcoin/blockchain/info
GET  /api/v1/bitcoin/blockchain/tip
GET  /api/v1/bitcoin/block/{hash}
GET  /api/v1/bitcoin/transaction/{txid}
GET  /api/v1/bitcoin/fee/estimate
POST /api/v1/bitcoin/transaction/decode
POST /api/v1/bitcoin/rpc  # Proxy direto (admin only)
```

**Exemplo - Fee Estimation:**
```bash
curl http://localhost:2121/api/v1/bitcoin/fee/estimate?blocks=6

# Response:
{
  "blocks": 6,
  "feerate_sat_vb": 12,
  "feerate_btc_kb": 0.00012000
}
```

#### 5. Liquid/Elements (`/api/v1/elements/*`)

**Função:** Operações Liquid (L-BTC e outros assets).

**Endpoints:**
```python
GET  /api/v1/elements/balances
POST /api/v1/elements/addresses
POST /api/v1/elements/send
GET  /api/v1/elements/utxos
GET  /api/v1/elements/transactions
GET  /api/v1/elements/info
POST /api/v1/elements/issue  # Emitir novo asset (advanced)
```

**Exemplo - Saldos Liquid:**
```bash
curl http://localhost:2121/api/v1/elements/balances \
  -H "Cookie: session_id=abc123"

# Response:
{
  "balances": {
    "lbtc": {
      "confirmed": 1000000,  # 0.01 L-BTC
      "unconfirmed": 0,
      "immature": 0
    },
    "usdt": {
      "confirmed": 50000000,  # 50 USDT
      "unconfirmed": 0
    }
  }
}
```

#### 6. Atomic Swaps (`/api/v1/swaps/*`) - **EM DESENVOLVIMENTO**

**Função:** Atomic swaps entre L-BTC, Lightning e Bitcoin.

**Endpoints Planejados:**
```python
POST /api/v1/swaps/lbtc/to-lightning/initiate
POST /api/v1/swaps/lbtc/from-lightning/initiate
GET  /api/v1/swaps/{swap_id}
GET  /api/v1/swaps/list
POST /api/v1/swaps/{swap_id}/claim
POST /api/v1/swaps/{swap_id}/refund
GET  /api/v1/swaps/{swap_id}/recovery-file
GET  /api/v1/swaps/peers/available
POST /api/v1/swaps/peers/announce
```

**Exemplo - Iniciar Swap L-BTC → Lightning:**
```bash
curl -X POST http://localhost:2121/api/v1/swaps/lbtc/to-lightning/initiate \
  -H "Content-Type: application/json" \
  -H "Cookie: session_id=abc123" \
  -d '{
    "peer_id": "03abc123...",
    "amount_sats": 1000000,
    "timeout_blocks": 288
  }'

# Response:
{
  "swap_id": "uuid-123",
  "state": "INITIATED",
  "htlc_address": "ex1q...",
  "payment_hash": "7f3e9a...",
  "timeout_block": 123744,
  "expires_at": "2026-01-15T15:00:00Z"
}
```

#### 7. LND Wallet Init (`/api/v1/lnd/wallet/*`)

**Função:** Inicializar/desbloquear wallet LND.

**Endpoints:**
```python
POST /api/v1/lnd/wallet/gen-seed      # Gerar seed aezeed
POST /api/v1/lnd/wallet/init          # Inicializar com seed
POST /api/v1/lnd/wallet/init-hd       # Inicializar com extended key
POST /api/v1/lnd/wallet/unlock        # Desbloquear wallet existente
```

#### 8. TRON GasFree Wallet (`/api/v1/tron/*`)

**Função:** Carteira TRON com pagamento de gas automatizado.

**Endpoints:**
```python
POST /api/v1/tron/wallet/create
GET  /api/v1/tron/wallet/balance
POST /api/v1/tron/transfer
GET  /api/v1/tron/transactions
```

### Arquitetura Modular da API

**Diretórios Especializados:**

```
/root/brln-os/api/
├── v1/
│   ├── app.py                    # 115+ endpoints Flask
│   ├── session_auth.py           # Auth session-based (5 min TTL)
│   ├── requirements.txt          # Dependencies
│   ├── *_pb2.py                  # gRPC stubs gerados
│   └── proto/                    # LND proto files
│
├── core/                         # SWAP LOGIC
│   ├── htlc.py                   # Hash Time Lock Contracts
│   ├── preimage.py               # Preimage generation/validation
│   ├── scriptbuilder.py          # Bitcoin scripts builder
│   ├── txbuilder.py              # Transaction construction
│   ├── liquid_submarine_swap.py  # L-BTC ↔ Lightning (TODO)
│   ├── swap_state_machine.py    # State transitions (TODO)
│   └── swap_recovery.py          # Recovery files (TODO)
│
├── lnd/                          # LND INTEGRATION
│   ├── client.py                 # Extended gRPC client
│   ├── invoice_manager.py        # Invoice lifecycle
│   └── payment_monitor.py        # Real-time payment tracking
│
├── liquid/                       # LIQUID INTEGRATION
│   ├── client.py                 # Elements RPC wrapper (TODO)
│   ├── asset_manager.py          # Asset operations (TODO)
│   └── transaction_manager.py    # TX lifecycle (TODO)
│
├── persistence/                  # DATABASE
│   ├── models.py                 # SQLAlchemy ORM (Swap, Peer, etc)
│   ├── database.py               # Connection pooling
│   └── migrations/               # Alembic migrations
│
├── network/                      # P2P NETWORK (futuro)
│   ├── tor_integration.py        # Tor hidden services
│   ├── discovery.py              # Peer discovery
│   ├── gossip.py                 # Gossip protocol
│   └── p2p_swap_coordinator.py   # P2P swap coordination
│
└── external/
    └── boltz_client.py           # Boltz Backend integration
```

### Diagrama: Fluxo de Requisições

```
1. Frontend (pages/bitcoin/js/main.js)
   └─ fetch('/api/v1/wallet/balance/onchain')

2. Apache (proxy reverso)
   └─ ProxyPass para localhost:2121

3. Flask API (api/v1/app.py)
   ├─ @require_auth decorator (valida session)
   ├─ Função get_onchain_balance()
   │  └─ bitcoin_rpc_client.call('getbalance')
   │
   ├─ Bitcoin Core RPC call (JSON-RPC HTTP)
   │  └─ Resposta: {"result": 0.05123456, "error": null}
   │
   └─ Retorna JSON
      └─ {"balance_sat": 5123456, "confirmed": 5123456, "unconfirmed": 0}

4. Frontend
   └─ Renderiza saldo na UI: "0.05123456 BTC"
```

---

## 2.3 Camada 3: Frontend (Static HTML/CSS/JS)

A interface do usuário é **completamente estática** (HTML/CSS/JavaScript puro), servida pelo Apache e comunicando com a API via HTTPS.

### Sistema de Navegação Iframe

**Conceito:** Header persistente com content area dinâmica.

**Estrutura:**

```
/var/www/html/
├── main.html                # Entry point (carrega header + content)
├── pages/
│   ├── home/
│   │   ├── index.html       # Dashboard principal
│   │   ├── index.css
│   │   └── index.js         # fetch('/api/v1/system/status')
│   │
│   └── components/
│       ├── header/
│       │   ├── header.html  # Navbar persistente
│       │   ├── header.css
│       │   └── header.js
│       │
│       ├── bitcoin/
│       │   ├── bitcoin.html
│       │   ├── bitcoin.css
│       │   └── js/main.js   # fetch('/api/v1/bitcoin/*')
│       │
│       ├── lightning/
│       │   ├── lightning.html
│       │   ├── lightning.css
│       │   └── js/main.js   # fetch('/api/v1/lightning/*')
│       │
│       ├── elements/
│       │   ├── elements.html
│       │   ├── elements.css
│       │   └── js/main.js   # fetch('/api/v1/elements/*')
│       │
│       ├── wallet/
│       │   ├── wallet.html  # HD wallet manager
│       │   ├── wallet.css
│       │   ├── js/main.js
│       │   └── lib/         # BIP39/32 libraries (JS)
│       │
│       ├── tron/
│       │   ├── tron.html
│       │   └── js/main.js
│       │
│       └── config/
│           ├── config.html  # System administration
│           └── js/main.js
```

**main.html (estrutura):**
```html
<!DOCTYPE html>
<html>
<head>
  <title>BRLN-OS</title>
  <link rel="stylesheet" href="/pages/components/header/header.css">
</head>
<body>
  <!-- Header persistente (sempre visível) -->
  <iframe id="header-frame" src="/pages/components/header/header.html"
          style="width:100%; height:80px; border:none;"></iframe>

  <!-- Content area (muda conforme navegação) -->
  <iframe id="content-frame" src="/pages/home/index.html"
          style="width:100%; height:calc(100vh - 80px); border:none;"></iframe>

  <script>
    // Listener para mudanças de página
    window.addEventListener('message', (event) => {
      if (event.data.action === 'navigate') {
        document.getElementById('content-frame').src = event.data.url;
      }
    });
  </script>
</body>
</html>
```

**header.html (navegação):**
```html
<nav>
  <img src="/favicon.ico" alt="BRLN-OS">
  <ul>
    <li><a href="#" onclick="navigate('/pages/home/index.html')">Home</a></li>
    <li><a href="#" onclick="navigate('/pages/components/bitcoin/bitcoin.html')">Bitcoin</a></li>
    <li><a href="#" onclick="navigate('/pages/components/lightning/lightning.html')">Lightning</a></li>
    <li><a href="#" onclick="navigate('/pages/components/elements/elements.html')">Liquid</a></li>
    <li><a href="#" onclick="navigate('/pages/components/wallet/wallet.html')">Wallet</a></li>
    <li><a href="#" onclick="navigate('/pages/components/config/config.html')">Config</a></li>
  </ul>
</nav>

<script>
function navigate(url) {
  window.parent.postMessage({action: 'navigate', url: url}, '*');
}
</script>
```

### Comunicação com API

**Padrão:** fetch() API com session cookies.

**Exemplo (bitcoin.js):**
```javascript
// Função para buscar saldo Bitcoin
async function fetchOnchainBalance() {
  try {
    const response = await fetch('https://localhost/api/v1/wallet/balance/onchain', {
      method: 'GET',
      credentials: 'include',  // Envia session cookie
      headers: {
        'Content-Type': 'application/json'
      }
    });

    if (response.status === 401) {
      // Não autenticado, redireciona para login
      window.location.href = '/pages/components/login/login.html';
      return;
    }

    const data = await response.json();

    if (data.status === 'success') {
      document.getElementById('balance').textContent =
        (data.balance_sat / 100000000).toFixed(8) + ' BTC';
    } else {
      console.error('Error:', data.message);
    }
  } catch (error) {
    console.error('Fetch error:', error);
  }
}

// Atualiza saldo a cada 30 segundos
setInterval(fetchOnchainBalance, 30000);
fetchOnchainBalance();  // Primeira chamada imediata
```

### Fluxo de Autenticação

**Cenário:** Usuário acessa interface pela primeira vez.

**Etapas:**

1. **Usuário acessa** `https://IP/`
2. **Apache serve** `main.html`
3. **main.html carrega** `header.html` e `home/index.html`
4. **home/index.js** tenta fetch(`/api/v1/system/status`)
5. **API retorna** 401 Unauthorized (sem session)
6. **Frontend redireciona** para `/pages/components/login/login.html`
7. **Usuário digita** master password
8. **Frontend faz** POST `/api/v1/auth/login` com `{password: "..."}`
9. **API valida** password, cria session, retorna cookie
10. **Frontend armazena** cookie (HTTP-only, Secure)
11. **Todas as requisições** subsequentes incluem cookie automaticamente
12. **Session expira** após 5 minutos de inatividade (renovada a cada request)

---

# 3. Super Wallet: Integração LND + Elements

O conceito de **"Super Wallet"** do BRLN-OS unifica três camadas de pagamento Bitcoin em uma única interface coerente, permitindo ao usuário gerenciar Bitcoin on-chain, Lightning e Liquid de forma integrada.

## 3.1 Conceito de "Super Wallet"

### Três Camadas Unificadas

A Super Wallet não é uma carteira tradicional. É um **orquestrador inteligente** que decide automaticamente qual camada usar baseado em:

- **Valor da transação**
- **Velocidade necessária**
- **Privacidade desejada**
- **Disponibilidade de liquidez**

```
┌─────────────────────────────────────────────────┐
│            USUÁRIO                              │
│  "Quero pagar 100,000 sats para Alice"         │
└────────────┬────────────────────────────────────┘
             │
    ┌────────▼────────┐
    │  BRLN Wallet    │
    │   Orchestrator  │
    │                 │
    │  Análise:       │
    │  - Valor: 100k  │
    │  - Urgência: Alta│
    │  - Privacidade: Med│
    └────────┬────────┘
             │
    ┌────────▼──────────────────────────────┐
    │  Decisão Automática:                  │
    │  • < 10k sats    → Lightning (instant)│
    │  • 10k-1M sats   → Liquid (1 min)     │
    │  • > 1M sats     → Bitcoin (10 min)   │
    │  • Priv. crítica → Liquid (confid.)   │
    └────────┬──────────────────────────────┘
             │
    ┌────────▼─────────┬──────────┬─────────┐
    │                  │          │         │
┌───▼────────┐  ┌─────▼──────┐ ┌▼─────────┐
│ Lightning  │  │   Liquid   │ │ Bitcoin  │
│ Invoice    │  │  L-BTC TX  │ │ UTXO TX  │
│ 100k sats  │  │  Confid.   │ │ On-chain │
│ Instant ⚡ │  │  1 min ⏱️  │ │ 10 min 🐢│
│ ~1 sat fee │  │  ~10 sat   │ │ ~1000 sat│
└────────────┘  └────────────┘ └──────────┘
         │              │            │
         └──────────────┴────────────┘
                    │
         Se necessário: ATOMIC SWAP
         (Lightning ↔ L-BTC ou BTC)
                    │
              ┌─────▼──────┐
              │   HTLC     │
              │  Script    │
              │ Trustless  │
              └────────────┘
```

### 1. Bitcoin On-Chain (via Bitcoin Core)

**Características:**
- **Segurança máxima:** Validação completa da blockchain
- **Finalidade definitiva:** Após 6 confirmações (~1 hora)
- **Capacidade:** Sem limites práticos (milhões de BTC)
- **Velocidade:** ~10 minutos (1 bloco)
- **Custo:** Variável (1-100 sat/vB dependendo de congestão)

**Quando usar:**
- Valores grandes (> 1M sats / 0.01 BTC)
- Pagamentos não urgentes
- Cold storage de longo prazo
- Quando liquidez Lightning não disponível

**Derivação de Chaves:**
- Path: `m/84'/0'/0'/0/N` (BIP84 - SegWit nativo)
- Endereços: `bc1q...` (mainnet) ou `tb1q...` (testnet)
- Type: P2WPKH (Pay to Witness Public Key Hash)

**Integração BRLN:**
- Backend: Bitcoin Core RPC (`getbalance`, `sendtoaddress`)
- Frontend: `pages/components/bitcoin/`
- API: `/api/v1/wallet/balance/onchain`, `/api/v1/wallet/transactions/send`

---

### 2. Lightning Network (via LND)

**Características:**
- **Velocidade:** Instantâneo (< 1 segundo)
- **Custo:** ~1-10 satoshis por pagamento
- **Capacidade:** Limitada pela liquidez de canais
- **Privacidade:** Boa (roteamento onion)

**Quando usar:**
- Valores pequenos (< 10k sats / $5)
- Pagamentos instantâneos (café, tips)
- Micropagamentos (streaming sats)
- Chat Lightning (keysend)

**Derivação de Chaves:**
- LND usa BIP32 extended private key
- Não usa BIP39 diretamente (usa aezeed proprietário)
- Integração: Converter BIP39 → BIP32 extended key via `/api/v1/lnd/wallet/init-hd`

**Integração BRLN:**
- Backend: LND gRPC (`AddInvoice`, `SendPayment`, `ListChannels`)
- Frontend: `pages/components/lightning/`
- API: `/api/v1/lightning/invoices`, `/api/v1/lightning/payments`

---

### 3. Liquid Network (via Elements)

**Características:**
- **Velocidade:** Blocos de 1 minuto
- **Privacidade:** Transações confidenciais (valores e assets ocultos)
- **Multi-asset:** L-BTC, USDT, stablecoins, issued assets
- **Custo:** ~10-50 satoshis por TX

**Quando usar:**
- Valores médios (10k-1M sats / $5-$500)
- Necessidade de confirmação rápida (< 2 minutos)
- Privacidade crítica (valores confidenciais)
- Multi-asset (USDT, stablecoins)
- Atomic swaps com Lightning

**Derivação de Chaves:**
- Path: `m/84'/1776'/0'/0/N` (coin_type 1776 para Liquid)
- Endereços: `ex1q...` (mainnet) ou `ert1q...` (testnet)
- Type: P2WPKH confidencial

**Assets Principais:**
- **L-BTC:** Bitcoin na Liquid (1:1 peg com BTC)
  - Asset ID: `6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d`
- **USDT:** Tether na Liquid
  - Asset ID: `ce091c998b83c78bb71a632313ba3760f1763d9cfcffae02258ffa9865a37bd2`
- **DePix:** Asset brasileiro
  - Asset ID: `02f22f8d9c76ab41661a2729e4752e2c5d1a263012141b86ea98af5472df5189`

**Integração BRLN:**
- Backend: Elements RPC (`getbalances`, `sendtoaddress`)
- Frontend: `pages/components/elements/`
- API: `/api/v1/elements/balances`, `/api/v1/elements/send`

---

## 3.2 Derivação de Chaves (BIP32/39/44)

### Master Seed BIP39 (24 palavras)

**O que é BIP39?**

BIP39 (Bitcoin Improvement Proposal 39) é um padrão para gerar seeds mnemônicos legíveis por humanos.

**Processo:**

```
1. Gerar Entropia (256 bits aleatórios)
   └─> [random bytes: 32 bytes]

2. Calcular Checksum (SHA256)
   └─> [primeiros 8 bits do hash]

3. Concatenar Entropia + Checksum
   └─> [264 bits total]

4. Dividir em grupos de 11 bits
   └─> [24 grupos de 11 bits]

5. Mapear para palavras da wordlist BIP39
   └─> ["abandon", "abandon", "abandon", ..., "art"]

6. Mnemonic Final (24 palavras)
   └─> "abandon abandon abandon ... art"
```

**Conversão para Seed (512 bits):**

```python
# PBKDF2 com 2048 iterações
mnemonic = "abandon abandon ... art"
passphrase = ""  # Opcional, adiciona segurança extra

seed = PBKDF2(
    password=mnemonic,
    salt="mnemonic" + passphrase,
    iterations=2048,
    keylen=64  # 512 bits
)
```

**Arquivo:** `/root/brln-os/brln-tools/bip39-tool.py`

---

### BIP32: Hierarchical Deterministic Wallets

**O que é BIP32?**

BIP32 define como derivar infinitas chaves a partir de um master seed.

**Estrutura:**

```
Master Seed (512 bits)
      │
      └─> Master Private Key + Master Chain Code
            │
            ├─> Child Key 0 (hardened)
            ├─> Child Key 1 (hardened)
            └─> Child Key 2 (hardened)
                  │
                  └─> Grandchild Key 0
                        │
                        └─> Great-grandchild Key 0
                              └─> ...
```

**Derivation Paths (BIP44):**

BIP44 define estrutura padrão de paths:

```
m / purpose' / coin_type' / account' / change / address_index

Onde:
- m: Master key
- purpose: 44' (BIP44), 49' (BIP49), 84' (BIP84)
- coin_type: 0' (Bitcoin), 60' (Ethereum), 195' (TRON), 1776' (Liquid)
- account: 0' (primeira conta)
- change: 0 (endereços de recebimento), 1 (endereços de troco)
- address_index: 0, 1, 2, ... (índice sequencial)

' indica "hardened" (derivação mais segura)
```

**Exemplos de Paths:**

| Network | Path | Endereço Exemplo |
|---------|------|------------------|
| Bitcoin SegWit | m/84'/0'/0'/0/0 | bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh |
| Liquid | m/84'/1776'/0'/0/0 | ex1q7n8v... |
| Ethereum | m/44'/60'/0'/0/0 | 0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb |
| TRON | m/44'/195'/0'/0/0 | TLsV52sRDL79HXGGm9yzwKibb6BeruhUzy |

---

### Integração LND: BIP39 → BIP32

**Problema:** LND usa aezeed proprietário, não BIP39 diretamente.

**Solução BRLN-OS:** Converter BIP39 → BIP32 extended private key.

**Código (simplificado):**

```python
from mnemonic import Mnemonic
from bip32 import BIP32

# 1. Gerar seed BIP39
mnemo = Mnemonic("english")
mnemonic = mnemo.generate(strength=256)  # 24 palavras

# 2. Converter para seed binário
seed = mnemo.to_seed(mnemonic, passphrase="")

# 3. Derivar master key BIP32
bip32 = BIP32.from_seed(seed)

# 4. Derivar path específico para Bitcoin (m/84'/0'/0')
account_xpriv = bip32.get_xpriv_from_path("m/84'/0'/0'")

# 5. Passar para LND
# lncli -n testnet createwallet --extended_key=account_xpriv
```

**Endpoint API:**

```bash
curl -X POST http://localhost:2121/api/v1/lnd/wallet/init-hd \
  -H "Content-Type: application/json" \
  -H "Cookie: session_id=abc123" \
  -d '{
    "mnemonic": "abandon abandon ... art",
    "wallet_password": "strong_password"
  }'
```

**Fluxo Interno:**

1. API recebe mnemonic
2. Converte para BIP32 extended private key
3. Chama gRPC `InitWallet` com extended_key
4. LND inicializa wallet e deriva todas as chaves necessárias
5. Retorna sucesso + admin.macaroon

**Arquivo:** `/root/brln-os/api/v1/app.py` (função `init_lnd_wallet_hd`)

---

### Integração Elements: BIP39 → HD Wallet

**Solução Elements:** `sethdseed` RPC command.

**Código (simplificado):**

```python
import hashlib
from mnemonic import Mnemonic

# 1. Mnemonic BIP39
mnemonic = "abandon abandon ... art"

# 2. Converter para seed
mnemo = Mnemonic("english")
seed_bytes = mnemo.to_seed(mnemonic, passphrase="")

# 3. Derivar seed hexadecimal
seed_hex = seed_bytes[:32].hex()  # Primeiros 32 bytes

# 4. Chamar Elements RPC
elements_rpc.call('sethdseed', [True, seed_hex])

# Agora Elements vai derivar endereços Liquid do mesmo seed!
```

**Endpoint API:**

```bash
curl -X POST http://localhost:2121/api/v1/wallet/integrate-elements \
  -H "Content-Type: application/json" \
  -H "Cookie: session_id=abc123" \
  -d '{
    "wallet_id": "main"
  }'
```

**Fluxo Interno:**

1. API carrega wallet criptografada do database
2. Descriptografa mnemonic com master password
3. Converte para seed hexadecimal
4. Chama Elements RPC `sethdseed`
5. Elements reinicia wallet com novo HD seed
6. Deriva endereços Liquid consistentes

**Arquivo:** `/root/brln-os/api/v1/app.py` (função `integrate_elements`)

---

## 3.3 Segurança: Master Password

A Super Wallet é protegida por um **master password** que o usuário define durante a instalação do BRLN-OS. Este password é usado para criptografar todos os dados sensíveis.

### Fluxo de Autenticação

**Cenário:** Usuário quer acessar a interface web.

**Etapas:**

```
┌─────────────────────────────────────────┐
│ 1. Usuário acessa https://IP/          │
└───────────────┬─────────────────────────┘
                │
┌───────────────▼─────────────────────────┐
│ 2. Frontend detecta: Sem session        │
│    Redireciona para /login              │
└───────────────┬─────────────────────────┘
                │
┌───────────────▼─────────────────────────┐
│ 3. Usuário digita master password       │
│    Form: <input type="password">        │
└───────────────┬─────────────────────────┘
                │
┌───────────────▼─────────────────────────┐
│ 4. POST /api/v1/auth/login              │
│    Body: {"password": "user_password"}  │
└───────────────┬─────────────────────────┘
                │
┌───────────────▼─────────────────────────┐
│ 5. API valida password                  │
│    - Carrega canary criptografado       │
│    - Tenta descriptografar com password │
│    - Se sucesso: password correto ✅    │
│    - Se falha: password errado ❌       │
└───────────────┬─────────────────────────┘
                │ (se válido)
┌───────────────▼─────────────────────────┐
│ 6. Cria sessão                          │
│    - session_id = UUID                  │
│    - session_data = {                   │
│        "user": "admin",                 │
│        "master_password": "encrypted",  │
│        "created_at": timestamp,         │
│        "expires_at": timestamp + 5min   │
│      }                                  │
│    - Armazena em Redis ou memória       │
└───────────────┬─────────────────────────┘
                │
┌───────────────▼─────────────────────────┐
│ 7. Retorna cookie HTTP-only             │
│    Set-Cookie: session_id=abc123;       │
│                HttpOnly; Secure;        │
│                SameSite=Strict          │
└───────────────┬─────────────────────────┘
                │
┌───────────────▼─────────────────────────┐
│ 8. Todas as requisições seguintes       │
│    incluem cookie automaticamente       │
│    Cookie: session_id=abc123            │
└───────────────┬─────────────────────────┘
                │
┌───────────────▼─────────────────────────┐
│ 9. Cada request renova TTL da sessão    │
│    (session_data.expires_at = now + 5min)│
└───────────────┬─────────────────────────┘
                │
┌───────────────▼─────────────────────────┐
│ 10. Após 5 min de inatividade:          │
│     Session expira automaticamente      │
│     Próximo request retorna 401         │
│     Frontend redireciona para /login    │
└─────────────────────────────────────────┘
```

**Arquivo:** `/root/brln-os/api/v1/session_auth.py`

---

### Criptografia de Seeds

**Tecnologia:** Fernet (AES-128-CBC + HMAC-SHA256) com PBKDF2 key derivation.

**Por que Fernet?**

- Criptografia autenticada (impossível modificar sem detectar)
- Biblioteca padrão Python (cryptography)
- Simples e seguro

**Processo de Criptografia:**

```python
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
import os

def encrypt_seed(mnemonic: str, master_password: str) -> dict:
    """
    Criptografa um mnemonic BIP39 com o master password.

    Retorna dict com:
    - encrypted_data: bytes criptografados
    - salt: salt usado no PBKDF2
    - iterations: número de iterações PBKDF2
    """
    # 1. Gerar salt aleatório (16 bytes)
    salt = os.urandom(16)

    # 2. Derivar chave de criptografia com PBKDF2
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,  # 256 bits
        salt=salt,
        iterations=600_000  # Recomendação OWASP 2023
    )
    key = kdf.derive(master_password.encode())

    # 3. Criar cipher Fernet
    fernet = Fernet(base64.urlsafe_b64encode(key))

    # 4. Criptografar mnemonic
    encrypted_data = fernet.encrypt(mnemonic.encode())

    # 5. Retornar dados para armazenamento
    return {
        'encrypted_data': encrypted_data,
        'salt': salt,
        'iterations': 600_000
    }

def decrypt_seed(encrypted_data: bytes, salt: bytes,
                 iterations: int, master_password: str) -> str:
    """
    Descriptografa um mnemonic BIP39.
    """
    # 1. Re-derivar chave de criptografia com mesmo salt
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=iterations
    )
    key = kdf.derive(master_password.encode())

    # 2. Criar cipher Fernet
    fernet = Fernet(base64.urlsafe_b64encode(key))

    # 3. Descriptografar
    try:
        decrypted_data = fernet.decrypt(encrypted_data)
        return decrypted_data.decode()
    except Exception as e:
        # Password incorreto ou dados corrompidos
        raise ValueError("Invalid password or corrupted data")
```

**Armazenamento no Database:**

```sql
CREATE TABLE wallets (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    encrypted_mnemonic BYTEA NOT NULL,  -- Fernet encrypted
    salt BYTEA NOT NULL,                -- PBKDF2 salt
    iterations INTEGER NOT NULL,        -- PBKDF2 iterations
    created_at TIMESTAMP DEFAULT NOW()
);
```

**Arquivo:** `/root/brln-os/brln-tools/secure_password_manager.py`

---

### Validação de Master Password (Canary)

**Problema:** Como validar se o password está correto sem armazenar hash do password?

**Solução:** Canary encryptado.

**Conceito:**

1. Durante instalação, criptografa string conhecida ("BRLN_CANARY")
2. Armazena canary criptografado
3. Para validar password: Tenta descriptografar canary
4. Se resultado == "BRLN_CANARY", password correto
5. Se falhar ou resultado diferente, password errado

**Código:**

```python
# Instalação (brunel.sh)
def setup_master_password():
    password = input("Enter master password: ")

    # Criptografa canary
    canary_data = encrypt_seed("BRLN_CANARY", password)

    # Salva em arquivo
    with open('/root/.brln/canary', 'wb') as f:
        import pickle
        pickle.dump(canary_data, f)

    print("✅ Master password configured!")

# Login (API)
def validate_password(password: str) -> bool:
    # Carrega canary
    with open('/root/.brln/canary', 'rb') as f:
        import pickle
        canary_data = pickle.load(f)

    # Tenta descriptografar
    try:
        result = decrypt_seed(
            canary_data['encrypted_data'],
            canary_data['salt'],
            canary_data['iterations'],
            password
        )
        return result == "BRLN_CANARY"
    except:
        return False
```

**Vantagens:**

- Não armazena hash do password (mais seguro)
- Usa mesma criptografia dos seeds (consistente)
- Resistente a timing attacks (comparação de strings constante via hmac.compare_digest)

---

### Segurança Adicional

**1. Rate Limiting**

Previne brute-force de passwords.

```python
from flask_limiter import Limiter

limiter = Limiter(app, key_func=lambda: request.remote_addr)

@app.route('/api/v1/auth/login', methods=['POST'])
@limiter.limit("5 per minute")  # Máximo 5 tentativas por minuto
def login():
    # ...validação de password...
```

**2. Session Timeout**

Sessões expiram após 5 minutos de inatividade.

```python
SESSION_TTL = 300  # 5 minutos em segundos

def is_session_valid(session_id: str) -> bool:
    session_data = session_store.get(session_id)

    if not session_data:
        return False

    if session_data['expires_at'] < time.time():
        session_store.delete(session_id)
        return False

    # Renova TTL
    session_data['expires_at'] = time.time() + SESSION_TTL
    session_store.set(session_id, session_data)

    return True
```

**3. HTTP-only Cookies**

Previne XSS (Cross-Site Scripting).

```python
response.set_cookie(
    'session_id',
    value=session_id,
    httponly=True,   # JavaScript não pode acessar
    secure=True,     # Apenas HTTPS
    samesite='Strict'  # Não envia em requests cross-site
)
```

**4. HTTPS Obrigatório**

Apache configurado para forçar HTTPS.

```apache
<VirtualHost *:80>
    Redirect permanent / https://localhost/
</VirtualHost>

<VirtualHost *:443>
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/brln-selfsigned.crt
    SSLCertificateKeyFile /etc/ssl/private/brln-selfsigned.key

    # HSTS (HTTP Strict Transport Security)
    Header always set Strict-Transport-Security "max-age=31536000"
</VirtualHost>
```

**Arquivo de Configuração:** `/root/brln-os/conf_files/brln-apache.conf`

---

# 4. Atomic Swaps: Fundamentos Técnicos

Esta é a seção mais crítica do documento, explicando como o BRLN-OS implementa **atomic swaps descentralizados** entre Lightning, Bitcoin e Liquid.

## 4.1 O que são Atomic Swaps

### Definição

**Atomic Swap** (troca atômica) é uma tecnologia que permite duas partes trocarem ativos criptográficos **sem intermediário**, com garantias matemáticas de que:

1. **Atomicidade:** Ou ambas as partes recebem seus fundos, ou nenhuma recebe (não há estado parcial)
2. **Trustlessness:** Nenhuma parte precisa confiar na outra ou em terceiro
3. **Descentralização:** Sem custódio central ou autoridade
4. **Segurança:** Garantias criptográficas (impossível roubar fundos da contraparte)

### Propriedades Fundamentais

**Atomicidade:**
```
Estado Inicial:
- Alice tem 0.01 L-BTC
- Bob tem 1M sats Lightning

Estado Final (sucesso):
- Alice tem 1M sats Lightning
- Bob tem 0.01 L-BTC

Estado Final (falha):
- Alice tem 0.01 L-BTC (devolvido)
- Bob tem 1M sats Lightning (nada mudou)

Impossível:
- Alice tem 0 L-BTC mas Bob não recebeu
- Bob pagou Lightning mas Alice não pagou L-BTC
```

**Trustlessness:**

Não é necessário:
- Confiar que a contraparte vai pagar depois de receber
- Confiar em exchange ou custódio
- Confiar em árbitro ou mediador
- Assinar contratos legais

Necessário apenas:
- Protocolo HTLC (matemática e criptografia)
- Blockchain funcionando (descentralizado)

**Descentralização:**

- Sem servidor central
- Sem ponto único de falha
- Sem KYC (Know Your Customer)
- Sem permissão necessária
- Resistente à censura

**Segurança:**

- Impossível roubar fundos bloqueados no HTLC
- Preimage secret garante atomicidade
- Timeout garante reembolso se swap falhar
- Impossível modificar termos do swap depois de iniciado

---

## 4.2 HTLC (Hash Time Lock Contract)

HTLC é a tecnologia fundamental que torna atomic swaps possíveis. É um **script Bitcoin** (ou contrato inteligente simples) com duas condições:

### Componente 1: Hash Lock

**Conceito:** Bloquear fundos que só podem ser gastos por quem conhece um "segredo" (preimage).

**Criptografia:**

```
┌────────────────────────────────────┐
│  Preimage (secreto)                │
│  32 bytes aleatórios               │
│  Exemplo: 0xabc123def456...        │
│  Gerado por: secrets.token_bytes(32)│
└──────────┬─────────────────────────┘
           │ SHA256 hash
           ▼
┌────────────────────────────────────┐
│  Payment Hash (público)            │
│  32 bytes hash                     │
│  Exemplo: 0x7f3e9a2b1c...          │
│  Calculado: SHA256(preimage)       │
└────────────────────────────────────┘
```

**Propriedades do Hash Lock:**

1. **One-way:** Impossível calcular preimage a partir do hash (SHA256 é unidirecional)
2. **Deterministic:** Mesmo preimage sempre produz mesmo hash
3. **Collision-resistant:** Impossível encontrar dois preimages diferentes com mesmo hash
4. **Public hash:** Payment hash pode ser compartilhado publicamente sem revelar segredo

**Uso no Swap:**

- **Alice** gera preimage (secreto)
- **Alice** calcula payment_hash = SHA256(preimage)
- **Alice** compartilha payment_hash com Bob (público)
- **Bob** cria HTLC que só pode ser gasto revelando preimage
- Quando Alice revela preimage para gastar HTLC de Bob, Bob descobre o preimage também!

**Código (Python):**

```python
import secrets
import hashlib

# Gerar preimage
preimage = secrets.token_bytes(32)
print(f"Preimage: {preimage.hex()}")
# Preimage: abc123def456...

# Calcular payment hash
payment_hash = hashlib.sha256(preimage).digest()
print(f"Payment Hash: {payment_hash.hex()}")
# Payment Hash: 7f3e9a2b1c...

# Verificar preimage
def verify_preimage(preimage: bytes, expected_hash: bytes) -> bool:
    actual_hash = hashlib.sha256(preimage).digest()
    return actual_hash == expected_hash

print(verify_preimage(preimage, payment_hash))  # True
```

**Arquivo:** `/root/brln-os/api/core/preimage.py`

---

### Componente 2: Time Lock

**Conceito:** Se o preimage não for revelado dentro de um prazo, permitir reembolso ao pagador original.

**Dois Tipos de Timelock:**

#### **1. Relative Timelock (CSV - CheckSequenceVerify)**

Tempo relativo desde a confirmação da transação.

```
OP_CHECKSEQUENCEVERIFY 144

Significa: "Estes fundos só podem ser gastos 144 blocos APÓS
           a confirmação desta transação"

Exemplo:
- HTLC funding TX confirmada no bloco 800,000
- Refund possível apenas após bloco 800,144 (800,000 + 144)
- 144 blocos ≈ 24 horas em Bitcoin (10 min/bloco)
```

#### **2. Absolute Timelock (CLTV - CheckLockTimeVerify)**

Tempo absoluto (número de bloco específico).

```
OP_CHECKLOCKTIMEVERIFY 800144

Significa: "Estes fundos só podem ser gastos APÓS bloco 800,144"

Exemplo:
- HTLC criado no bloco 800,000
- Timeout set para bloco 800,144
- Refund possível apenas após bloco 800,144
```

**BRLN-OS usa CSV** (relative timelock) para flexibilidade.

**Código (Bitcoin Script):**

```
<timeout_blocks> OP_CHECKSEQUENCEVERIFY

Onde timeout_blocks é um número inteiro:
- 144 blocos = 24 horas (Bitcoin)
- 288 blocos = 4.8 horas (Liquid, blocos de 1 min)
```

---

### HTLC Script Completo

**Script Bitcoin (assembly-like):**

```
OP_IF
    # Caminho 1: CLAIM (Receiver revela preimage)
    OP_SHA256
    <payment_hash>
    OP_EQUALVERIFY
    <receiver_pubkey>
OP_ELSE
    # Caminho 2: REFUND (Sender recupera após timeout)
    <timeout_blocks>
    OP_CHECKSEQUENCEVERIFY
    OP_DROP
    <sender_pubkey>
OP_ENDIF
OP_CHECKSIG
```

**Interpretação:**

```
SE (stack top = 1):
    # Caminho CLAIM
    - Pegue dados do stack (preimage)
    - Calcule SHA256(preimage)
    - Verifique se resultado == payment_hash
    - Se não, FALHA
    - Verifique assinatura do receiver_pubkey
    - Se válida, SUCESSO (fundos liberados)

SENÃO (stack top = 0):
    # Caminho REFUND
    - Verifique se passaram timeout_blocks desde confirmação
    - Se não, FALHA
    - Verifique assinatura do sender_pubkey
    - Se válida, SUCESSO (reembolso)
```

**Visualização:**

```
┌───────────────────────────────────────────────┐
│           HTLC Script                         │
├───────────────────────────────────────────────┤
│                                               │
│  Caminho 1: CLAIM (Revelar Preimage)         │
│  ┌─────────────────────────────────┐         │
│  │ Input:                          │         │
│  │  - preimage (32 bytes)          │         │
│  │  - receiver_signature           │         │
│  │  - 1 (flag)                     │         │
│  └─────────────────────────────────┘         │
│           │                                   │
│           ▼                                   │
│  ┌─────────────────────────────────┐         │
│  │ Validação:                      │         │
│  │  ✓ SHA256(preimage) == hash?   │         │
│  │  ✓ Signature válida?            │         │
│  └─────────────────────────────────┘         │
│           │                                   │
│           ▼                                   │
│      SUCESSO ✅                               │
│      Fundos liberados para Receiver          │
│                                               │
├───────────────────────────────────────────────┤
│                                               │
│  Caminho 2: REFUND (Timeout)                 │
│  ┌─────────────────────────────────┐         │
│  │ Input:                          │         │
│  │  - sender_signature             │         │
│  │  - 0 (flag)                     │         │
│  └─────────────────────────────────┘         │
│           │                                   │
│           ▼                                   │
│  ┌─────────────────────────────────┐         │
│  │ Validação:                      │         │
│  │  ✓ Timeout passou?              │         │
│  │  ✓ Signature válida?            │         │
│  └─────────────────────────────────┘         │
│           │                                   │
│           ▼                                   │
│      SUCESSO ♻️                               │
│      Fundos devolvidos para Sender           │
│                                               │
└───────────────────────────────────────────────┘
```

**Arquivo:** `/root/brln-os/api/core/scriptbuilder.py`

**Código Python (construção do script):**

```python
from bitcoin import SelectParams, encode
from bitcoin.core.script import *

def build_htlc_script(payment_hash: bytes,
                       receiver_pubkey: bytes,
                       sender_pubkey: bytes,
                       timeout_blocks: int) -> CScript:
    """
    Constrói HTLC script para Bitcoin ou Liquid.

    Args:
        payment_hash: SHA256 hash do preimage (32 bytes)
        receiver_pubkey: Chave pública do receiver (33 bytes compressed)
        sender_pubkey: Chave pública do sender (33 bytes compressed)
        timeout_blocks: Número de blocos para timeout (CSV)

    Returns:
        CScript: Bitcoin script compilado
    """
    script = CScript([
        OP_IF,
            # Caminho CLAIM
            OP_SHA256,
            payment_hash,
            OP_EQUALVERIFY,
            receiver_pubkey,
        OP_ELSE,
            # Caminho REFUND
            timeout_blocks,
            OP_CHECKSEQUENCEVERIFY,
            OP_DROP,
            sender_pubkey,
        OP_ENDIF,
        OP_CHECKSIG
    ])

    return script

# Exemplo de uso
payment_hash = bytes.fromhex("7f3e9a2b1c...")
receiver_pubkey = bytes.fromhex("03abc123...")
sender_pubkey = bytes.fromhex("02def456...")
timeout_blocks = 144  # 24 horas

htlc_script = build_htlc_script(
    payment_hash,
    receiver_pubkey,
    sender_pubkey,
    timeout_blocks
)

print(f"HTLC Script: {htlc_script.hex()}")
```

---

### Endereço P2WSH (Pay to Witness Script Hash)

**O que é P2WSH?**

P2WSH (BIP141) é um tipo de endereço SegWit que paga para o hash de um script (witness script). É usado para scripts complexos como HTLCs.

**Processo:**

```
1. HTLC Script (script completo)
   └─> SHA256
       └─> Script Hash (32 bytes)
           └─> Bech32 encode
               └─> Endereço bc1q... (Bitcoin) ou ex1q... (Liquid)
```

**Código:**

```python
import hashlib
from bitcoin import SelectParams, encode
from bitcoin.core import COIN
from bitcoin.wallet import P2WSHBitcoinAddress

def script_to_p2wsh_address(script: CScript, network: str = 'testnet') -> str:
    """
    Converte script para endereço P2WSH.

    Args:
        script: Bitcoin script (HTLC)
        network: 'mainnet' ou 'testnet'

    Returns:
        str: Endereço P2WSH (bc1q... ou tb1q...)
    """
    SelectParams(network)

    # Calcular script hash (SHA256)
    script_hash = hashlib.sha256(script).digest()

    # Criar endereço P2WSH
    address = P2WSHBitcoinAddress.from_scriptPubKey(
        CScript([OP_0, script_hash])
    )

    return str(address)

# Exemplo
htlc_script = build_htlc_script(...)
htlc_address = script_to_p2wsh_address(htlc_script, 'testnet')
print(f"HTLC Address: {htlc_address}")
# Output: tb1q4v8k2np9f7j8w3x5h2m9c0a1b6d8e7f...
```

**Alice envia L-BTC para este endereço** → Fundos bloqueados pelo HTLC!

---

## 4.3 Estados do Swap

O ciclo de vida de um atomic swap passa por múltiplos estados, gerenciados por uma **máquina de estados**.

### Máquina de Estados

```
┌─────────────┐
│  INITIATED  │  Swap criado, preimage gerado
└──────┬──────┘
       │
       │ Funding TX confirmada
       ▼
┌─────────────┐
│   FUNDED    │  Fundos bloqueados no HTLC
└──────┬──────┘
       │
       ├───── Preimage revelado ─────┐
       │                             │
       ▼                             │
┌─────────────┐                      │
│   CLAIMED   │ ✅ Swap completo     │
└─────────────┘                      │
       │                             │
       └─ Preimage deletado          │
                                     │
       ┌─────────────────────────────┘
       │ Timeout expirou
       ▼
┌─────────────┐
│   EXPIRED   │  Timeout passou, nenhuma claim
└──────┬──────┘
       │
       │ Refund TX confirmada
       ▼
┌─────────────┐
│  REFUNDED   │ ♻️ Fundos devolvidos
└─────────────┘

       ┌──────── Qualquer estado
       │
       │ Erro irrecuperável
       ▼
┌─────────────┐
│   FAILED    │ ❌ Swap falhou
└─────────────┘
```

### Descrição dos Estados

#### **INITIATED**

**Quando:** Swap criado, preimage gerado, HTLC script construído.

**Dados:**
- `swap_id` (UUID)
- `swap_type` (LBTC_TO_LIGHTNING)
- `state` = INITIATED
- `payment_hash` (32 bytes hex)
- `preimage` (32 bytes hex, criptografado)
- `htlc_script` (hex)
- `htlc_address` (bc1q... ou ex1q...)
- `timeout_block_height`
- `initiator_peer_id`
- `receiver_peer_id`
- `amount_satoshis`
- `created_at`
- `expires_at`

**Próximas Ações:**
- Alice: Enviar fundos para `htlc_address`
- Sistema: Monitorar blockchain para funding TX

**Arquivo:** `/root/brln-os/api/persistence/models.py` (Swap model, SwapState.INITIATED)

---

#### **FUNDED**

**Quando:** Funding TX confirmada on-chain.

**Mudanças:**
- `state` = FUNDED
- `funding_txid` (hex)
- `funding_block_height`
- `funded_at` (timestamp)

**Próximas Ações:**
- Bob: Criar Lightning invoice com mesmo `payment_hash`
- Alice: Pagar invoice Lightning
- Sistema: Monitorar pagamento Lightning e extração de preimage

**Timeout Clock:** Começa a contar! Se não houver claim antes de `timeout_block_height`, elegível para refund.

---

#### **CLAIMED**

**Quando:** Receiver revelou preimage e gastou HTLC.

**Mudanças:**
- `state` = CLAIMED
- `claim_txid` (hex)
- `claim_block_height`
- `completed_at` (timestamp)

**Ações Finais:**
- **Deletar preimage** do database (segurança)
- Atualizar reputação dos peers (+10 pontos)
- Marcar swap como completo

**Status Final:** ✅ **SUCESSO** - Swap atômico completado!

**Arquivo:** `/root/brln-os/api/core/liquid_submarine_swap.py` (handle_claim)

---

#### **EXPIRED**

**Quando:** Timeout passou, nenhuma claim transaction detectada.

**Condição:**
```python
current_block_height > swap.timeout_block_height
```

**Mudanças:**
- `state` = EXPIRED

**Próximas Ações:**
- Alice: Criar e broadcast refund TX
- Sistema: Monitorar refund TX

---

#### **REFUNDED**

**Quando:** Refund TX confirmada on-chain.

**Mudanças:**
- `state` = REFUNDED
- `refund_txid` (hex)
- `refund_block_height`
- `completed_at` (timestamp)

**Status Final:** ♻️ **REEMBOLSADO** - Fundos devolvidos para sender.

---

#### **FAILED**

**Quando:** Erro irrecuperável (TX inválida, peer offline permanentemente, etc).

**Mudanças:**
- `state` = FAILED
- `error_message` (texto descritivo)

**Status Final:** ❌ **FALHA** - Swap não completado.

**Nota:** Fundos ainda podem ser recuperados via refund após timeout.

---

### Código (SwapState Enum)

**Arquivo:** `/root/brln-os/api/persistence/models.py`

```python
from enum import Enum
from sqlalchemy import Column, String, Enum as SQLEnum

class SwapState(str, Enum):
    """Estados possíveis de um swap."""
    INITIATED = "INITIATED"
    FUNDED = "FUNDED"
    CLAIMED = "CLAIMED"
    EXPIRED = "EXPIRED"
    REFUNDED = "REFUNDED"
    FAILED = "FAILED"

class Swap(Base):
    __tablename__ = 'swaps'

    id = Column(UUID(as_uuid=True), primary_key=True)
    state = Column(SQLEnum(SwapState), nullable=False, default=SwapState.INITIATED)

    # ...outros campos...

    def can_claim(self) -> bool:
        """Verifica se swap pode ser claimed."""
        return self.state == SwapState.FUNDED

    def can_refund(self, current_block_height: int) -> bool:
        """Verifica se swap pode ser refunded."""
        return (
            self.state in [SwapState.FUNDED, SwapState.EXPIRED] and
            current_block_height > self.timeout_block_height
        )

    def mark_funded(self, funding_txid: str, block_height: int):
        """Marca swap como funded."""
        self.state = SwapState.FUNDED
        self.funding_txid = funding_txid
        self.funding_block_height = block_height
        self.funded_at = datetime.utcnow()

    def mark_claimed(self, claim_txid: str, block_height: int):
        """Marca swap como claimed."""
        self.state = SwapState.CLAIMED
        self.claim_txid = claim_txid
        self.claim_block_height = block_height
        self.completed_at = datetime.utcnow()

    def mark_expired(self):
        """Marca swap como expired."""
        self.state = SwapState.EXPIRED

    def mark_refunded(self, refund_txid: str, block_height: int):
        """Marca swap como refunded."""
        self.state = SwapState.REFUNDED
        self.refund_txid = refund_txid
        self.refund_block_height = block_height
        self.completed_at = datetime.utcnow()

    def mark_failed(self, error_message: str):
        """Marca swap como failed."""
        self.state = SwapState.FAILED
        self.error_message = error_message
```

---

## 4.4 Tipos de Swaps Implementados

O BRLN-OS suporta **9 tipos de atomic swaps** entre diferentes redes. Aqui estão os principais:

### 1. Submarine Swap: L-BTC → Lightning

**Cenário:** Usuário tem L-BTC, quer receber Lightning.

**Atores:**
- **Alice** (Initiator): Tem 0.01 L-BTC, quer 1M sats Lightning
- **Bob** (Responder): Tem liquidez Lightning, quer L-BTC

**Fluxo Resumido:**

```
1. Alice gera preimage (secreto)
   payment_hash = SHA256(preimage)

2. Alice cria HTLC na Liquid
   Script: "Pague para quem revelar preimage OU refund após 288 blocos"
   Alice envia 0.01 L-BTC para HTLC address

3. Bob cria Lightning invoice
   invoice = lnd.add_invoice(payment_hash, 1M sats)
   Bob envia invoice para Alice

4. Alice paga invoice Lightning
   Lightning Network roteia pagamento

5. Bob recebe pagamento
   Lightning FORÇA Bob a revelar preimage para receber sats
   Preimage agora público na rede Lightning

6. Bob extrai preimage e reclama L-BTC
   Bob cria TX gastando HTLC Liquid com preimage
   Bob recebe 0.01 L-BTC

Resultado: Alice tem 1M sats Lightning ⚡
           Bob tem 0.01 L-BTC 💧
```

**Diagrama Detalhado:**

```
Alice (tem L-BTC)                HTLC Liquid             Bob (fornece Lightning)
        │                             │                           │
        ├─1. Gera preimage ───────────┤                           │
        │   (secreto)                 │                           │
        │                             │                           │
        ├─2. Envia L-BTC ────────────>│                           │
        │   (funding TX)              │                           │
        │                             │                           │
        │                          3. Funded                      │
        │                             │<──────────────────────────┤
        │                             │   4. Cria Lightning       │
        │                             │      invoice              │
        │<────────────────────────────┼───────────────────────────┤
        │   5. Recebe invoice         │                           │
        │      (BOLT11)               │                           │
        │                             │                           │
        ├─6. Paga invoice ────────────┼──────────────────────────>│
        │   (Lightning)               │   7. Recebe pagamento     │
        │                             │      (preimage revelado)  │
        │                             │<──────────────────────────┤
        │                             │   8. Extrai preimage      │
        │                             │                           │
        │                             │   9. Cria claim TX        │
        │                             │<──────────────────────────┤
        │                             │   (gasta HTLC c/preimage) │
        │                             │                           │
        │                             └───────────────────────────>│
        │                                 10. Bob recebe L-BTC    │
        │                                                          │
        └──────────────────── ✅ SWAP COMPLETO ───────────────────┘
        Alice: 1M sats ⚡                        Bob: 0.01 L-BTC 💧
```

**Código (iniciar swap):**

```python
# POST /api/v1/swaps/lbtc/to-lightning/initiate
def initiate_lbtc_to_lightning_swap(peer_id: str,
                                     amount_sats: int,
                                     timeout_blocks: int = 288):
    """
    Alice inicia submarine swap L-BTC → Lightning.

    Args:
        peer_id: ID do peer (Bob)
        amount_sats: Quantidade em satoshis
        timeout_blocks: Timeout em blocos Liquid (default 288 = 4.8h)
    """
    # 1. Gerar preimage
    preimage = generate_preimage()
    payment_hash = sha256(preimage)

    # 2. Construir HTLC script
    alice_pubkey = get_alice_pubkey()
    bob_pubkey = get_peer_pubkey(peer_id)

    htlc_script = build_htlc_script(
        payment_hash=payment_hash,
        receiver_pubkey=bob_pubkey,
        sender_pubkey=alice_pubkey,
        timeout_blocks=timeout_blocks
    )

    # 3. Gerar HTLC address
    htlc_address = script_to_p2wsh_address(htlc_script, network='liquid')

    # 4. Calcular timeout block height
    current_block = get_liquid_block_height()
    timeout_block_height = current_block + timeout_blocks

    # 5. Salvar no database
    swap = Swap(
        id=uuid4(),
        swap_type=SwapType.LBTC_TO_LIGHTNING,
        state=SwapState.INITIATED,
        payment_hash=payment_hash.hex(),
        preimage=encrypt_preimage(preimage),  # Criptografado!
        htlc_script_hex=htlc_script.hex(),
        htlc_address=htlc_address,
        timeout_block_height=timeout_block_height,
        initiator_peer_id=get_current_user_peer_id(),
        receiver_peer_id=peer_id,
        amount_satoshis=amount_sats,
        created_at=datetime.utcnow(),
        expires_at=datetime.utcnow() + timedelta(hours=4.8)
    )
    db.session.add(swap)
    db.session.commit()

    # 6. Notificar Bob via P2P
    notify_peer(peer_id, 'SWAP_REQUEST', {
        'swap_id': str(swap.id),
        'payment_hash': payment_hash.hex(),
        'amount_sats': amount_sats,
        'timeout_blocks': timeout_blocks
    })

    # 7. Retornar info para Alice
    return {
        'swap_id': str(swap.id),
        'htlc_address': htlc_address,
        'payment_hash': payment_hash.hex(),
        'amount_sats': amount_sats,
        'timeout_block': timeout_block_height,
        'expires_at': swap.expires_at.isoformat(),
        'next_step': f'Send {amount_sats} sats L-BTC to {htlc_address}'
    }
```

**Arquivo:** `/root/brln-os/api/core/liquid_submarine_swap.py` (TODO)

---

### 2. Reverse Submarine Swap: Lightning → L-BTC

**Cenário:** Usuário tem Lightning, quer receber L-BTC.

**Fluxo:** Inverso do anterior.

```
1. Bob gera preimage
2. Bob cria HTLC na Liquid
3. Alice cria Lightning invoice com payment_hash de Bob
4. Bob paga invoice (revela preimage na Lightning)
5. Alice extrai preimage e reclama L-BTC
```

**Diferença Principal:** Quem gera preimage é o **responder** (Bob), não o initiator.

---

### 3. On-Chain Swap: BTC ↔ L-BTC

**Cenário:** Trocar Bitcoin mainnet por Liquid (ou vice-versa).

**Fluxo:**

```
1. Alice gera preimage
2. Alice cria HTLC em Bitcoin (10 min blocos, timeout 144 blocos)
3. Bob cria HTLC em Liquid (1 min blocos, timeout 288 blocos)
4. Alice reclama L-BTC de Bob (revela preimage)
5. Bob reclama BTC de Alice (usando mesmo preimage)
```

**Timeouts Assimétricos:**

- Bitcoin: 144 blocos (~24 horas)
- Liquid: 288 blocos (~4.8 horas)

**Razão:** Liquid tem blocos mais rápidos, então precisa de mais blocos para mesmo tempo absoluto.

---

### 4. Liquid Assets Swap

**Cenário:** Trocar L-BTC por USDT (ambos na Liquid).

**Simplificação:** Ambos os HTLCs na mesma chain (Liquid), apenas asset IDs diferentes.

---

## 4.5 Segurança: Timeouts e Reorgs

### Problema: Blockchain Reorganization

**O que é Reorg?**

Ocasionalmente, a blockchain Bitcoin (ou Liquid) pode sofrer uma "reorganização" onde alguns blocos recentes são invalidados e substituídos por uma cadeia alternativa.

**Exemplo:**

```
Cadeia Original:
... → Bloco 800,000 → Bloco 800,001 → Bloco 800,002

Reorg (2 blocos):
... → Bloco 800,000 → Bloco 800,001' → Bloco 800,002'
                      (diferente)      (diferente)

Blocos 800,001 e 800,002 originais são "órfãos"
Transações neles podem desaparecer ou mudar de confirmações
```

**Risco para Swaps:**

- HTLC funding TX pode "desconfirmar" temporariamente
- Claim TX pode ser revertida
- Timeout block height pode mudar

### Solução: Safety Margins

**Conceito:** Nunca considere TX segura até que tenha confirmações suficientes ALÉM do timeout.

**Constantes de Rede:**

**Arquivo:** `/root/brln-os/api/core/htlc.py`

```python
from enum import Enum

class NetworkType(str, Enum):
    BITCOIN_MAINNET = "bitcoin_mainnet"
    BITCOIN_TESTNET = "bitcoin_testnet"
    LIQUID_MAINNET = "liquid_mainnet"
    LIQUID_TESTNET = "liquid_testnet"

NETWORK_CONSTANTS = {
    NetworkType.BITCOIN_MAINNET: {
        'reorg_safety_blocks': 6,    # 6 confirmações (~1 hora)
        'min_timeout_blocks': 144,   # 24 horas
        'max_timeout_blocks': 2016,  # 2 semanas
        'block_time_seconds': 600,   # 10 minutos
    },
    NetworkType.BITCOIN_TESTNET: {
        'reorg_safety_blocks': 6,
        'min_timeout_blocks': 144,
        'max_timeout_blocks': 2016,
        'block_time_seconds': 600,
    },
    NetworkType.LIQUID_MAINNET: {
        'reorg_safety_blocks': 2,    # Liquid é mais centralizado
        'min_timeout_blocks': 288,   # 4.8 horas
        'max_timeout_blocks': 4320,  # 3 dias
        'block_time_seconds': 60,    # 1 minuto
    },
    NetworkType.LIQUID_TESTNET: {
        'reorg_safety_blocks': 2,
        'min_timeout_blocks': 24,    # 24 minutos (para testes)
        'max_timeout_blocks': 1440,
        'block_time_seconds': 60,
    },
}

class HTLC:
    def __init__(self, ..., network: NetworkType):
        self.network = network
        self.constants = NETWORK_CONSTANTS[network]
        # ...

    def is_safely_funded(self, current_block_height: int) -> bool:
        """
        Verifica se funding TX tem confirmações suficientes.
        """
        if not self.funding_block_height:
            return False

        confirmations = current_block_height - self.funding_block_height
        required_confs = self.constants['reorg_safety_blocks']

        return confirmations >= required_confs

    def can_refund_safely(self, current_block_height: int) -> bool:
        """
        Verifica se refund é seguro (timeout + safety margin).
        """
        if current_block_height <= self.timeout_block_height:
            return False  # Timeout ainda não passou

        blocks_since_timeout = current_block_height - self.timeout_block_height
        safety_margin = self.constants['reorg_safety_blocks']

        # Só refund após safety margin
        return blocks_since_timeout >= safety_margin
```

**Regra de Ouro:**

```
Refund seguro apenas quando:
current_block_height > timeout_block_height + reorg_safety_blocks

Exemplo (Bitcoin):
- Timeout: bloco 800,144
- Safety margin: 6 blocos
- Refund seguro: bloco 800,150 (800,144 + 6)
```

### Timeouts Assimétricos

**Por que timeouts diferentes em Bitcoin vs Liquid?**

```
Bitcoin:
- Blocos de ~10 minutos
- 144 blocos = 24 horas

Liquid:
- Blocos de ~1 minuto
- 288 blocos = 4.8 horas
- Mesmo tempo absoluto ≈ Bitcoin

Regra:
timeout_liquid = timeout_bitcoin * (bitcoin_block_time / liquid_block_time)
              = 144 * (10 / 1)
              = 1440 blocos

Mas usamos 288 blocos para swaps mais rápidos (4.8h suficiente)
```

---

# 5. Rede P2P: Descoberta e Coordenação

O BRLN-OS implementa uma **rede peer-to-peer descentralizada** para descoberta de peers e coordenação de atomic swaps. Esta seção descreve como os nós BRLN-OS se encontram e executam swaps sem servidor central.

## 5.1 Arquitetura de Rede

### Três Camadas de Conectividade

A rede P2P do BRLN-OS suporta três métodos de conexão, priorizados por privacidade e conveniência:

```
┌─────────────────────────────────────────────────┐
│       Camada 1: Lightning Network (Priority)    │
│                                                  │
│  Peers com canais Lightning existentes          │
│  • Comunicação via TLV custom records           │
│  • Keysend para mensagens                       │
│  • Latência baixíssima (< 1s)                   │
│  • Já autenticado (Lightning pubkey)            │
└─────────────────────────────────────────────────┘
                      │
                      ▼ Fallback se sem canal
┌─────────────────────────────────────────────────┐
│       Camada 2: Tor Hidden Services             │
│                                                  │
│  Peers sem canais Lightning diretos             │
│  • Onion addresses v3 (xyz.onion:port)          │
│  • Privacidade máxima (IP oculto)               │
│  • Latência média (2-5s)                        │
│  • Resistente à censura                         │
└─────────────────────────────────────────────────┘
                      │
                      ▼ Fallback se Tor indisponível
┌─────────────────────────────────────────────────┐
│       Camada 3: Direct IP (Opcional)            │
│                                                  │
│  Apenas para redes locais privadas              │
│  • IP:port direto (192.168.x.x)                 │
│  • Sem privacidade (IP exposto)                 │
│  • Latência mínima (< 100ms)                    │
│  • NÃO RECOMENDADO para internet pública        │
└─────────────────────────────────────────────────┘
```

**Priorização:**

1. **Lightning first:** Se existe canal Lightning com peer, usar keysend
2. **Tor fallback:** Se não há canal, usar Tor hidden service
3. **Direct IP:** Apenas para desenvolvimento/testes locais

---

### Database de Peers

**Modelo:** `/root/brln-os/api/persistence/models.py` (classe `Peer`)

**Campos Principais:**

```python
class Peer(Base):
    __tablename__ = 'peers'

    id = UUID                        # UUID único
    peer_pubkey = String(66)         # Lightning node pubkey (33 bytes hex)
    peer_alias = String(128)         # Nome amigável

    # Conexão
    connection_type = Enum(ConnectionType)  # LIGHTNING, TOR, DIRECT
    tor_onion_address = String(128)         # xyz.onion:9999
    lnd_node_uri = String(256)              # pubkey@host:port

    # Status
    last_seen_at = DateTime          # Última comunicação
    is_active = Boolean              # Peer online?

    # Reputação
    reputation_score = Integer       # 0-100+
    successful_swaps = Integer       # Swaps completados
    failed_swaps = Integer           # Swaps falhados

    # Capacidades
    supported_swap_types = JSON      # [LBTC_TO_LIGHTNING, ...]
    supported_assets = JSON          # ["lbtc", "usdt", ...]
```

**Índices para Performance:**

```sql
CREATE INDEX idx_peer_active_lastseen ON peers(is_active, last_seen_at);
CREATE INDEX idx_peer_reputation ON peers(reputation_score DESC);
```

**Query: Peers Disponíveis para Swap:**

```python
def get_available_peers_for_swap(swap_type: SwapDirection,
                                   min_reputation: int = 50) -> List[Peer]:
    """
    Retorna peers disponíveis para um tipo de swap.
    """
    return session.query(Peer).filter(
        Peer.is_active == True,
        Peer.reputation_score >= min_reputation,
        Peer.last_seen_at > datetime.utcnow() - timedelta(hours=1),
        Peer.supported_swap_types.contains([swap_type.value])
    ).order_by(Peer.reputation_score.desc()).all()
```

---

## 5.2 Descoberta de Peers

### Método 1: Via Lightning Graph

**Conceito:** Descobrir peers BRLN-OS via Lightning Network graph.

**Feature Flag:** Nodes BRLN-OS anunciam suporte a atomic swaps via Lightning node alias ou feature bits.

**Processo:**

```python
def discover_peers_via_lightning():
    """
    Descobre peers BRLN-OS via Lightning graph.
    """
    # 1. Query Lightning graph completo
    graph = lnd_client.describe_graph()

    # 2. Filtrar nodes com feature flag BRLN_SWAP
    brln_nodes = []
    for node in graph.nodes:
        # Verificar se alias contém "BRLN" ou feature bit específico
        if "BRLN" in node.alias or has_brln_feature_bit(node.features):
            brln_nodes.append(node)

    # 3. Tentar conectar via Lightning first
    for node in brln_nodes:
        try:
            # Se não há canal, tentar conectar peer
            if not has_channel_with(node.pub_key):
                lnd_client.connect_peer(node.pub_key, node.addresses[0])

            # Adicionar ao database de peers
            add_peer(
                peer_pubkey=node.pub_key,
                peer_alias=node.alias,
                connection_type=ConnectionType.LIGHTNING,
                lnd_node_uri=f"{node.pub_key}@{node.addresses[0]}"
            )
        except Exception as e:
            logger.warning(f"Failed to connect to {node.alias}: {e}")
```

**Vantagens:**
- Descoberta automática
- Peers já têm Lightning setup
- Autenticação nativa (Lightning signatures)

**Desvantagens:**
- Requer Lightning Network público
- Pode expor que você roda BRLN-OS

---

### Método 2: Via Tor Directory

**Conceito:** Diretório público de Tor onion addresses de peers BRLN-OS.

**Opção A: DHT (Distributed Hash Table)**

Similar ao BitTorrent DHT, mas para onion addresses.

**Opção B: Gossip Protocol**

Peers compartilham lista de outros peers conhecidos.

**Opção C: Servidor de Directory (centralizado, não ideal)**

Servidor mantém lista de onion addresses. **Evitar** devido à centralização.

**Implementação Recomendada: Gossip Protocol**

```python
def announce_self_to_network():
    """
    Anuncia próprio onion address para peers conhecidos.
    """
    my_onion = get_my_tor_onion_address()

    announcement = {
        'type': 'PEER_ANNOUNCEMENT',
        'peer_pubkey': get_my_lightning_pubkey(),
        'peer_alias': get_my_alias(),
        'onion_address': my_onion,
        'supported_swaps': ['LBTC_TO_LIGHTNING', 'LIGHTNING_TO_LBTC'],
        'supported_assets': ['lbtc', 'btc'],
        'timestamp': int(time.time()),
        'signature': sign_message(my_onion)  # Prova de posse da chave
    }

    # Enviar para todos os peers conhecidos
    for peer in get_all_peers():
        send_message_to_peer(peer.id, announcement)
```

**Arquivo:** `/root/brln-os/api/network/tor_integration.py` (TODO)

---

## 5.3 Gossip Protocol

### Mensagens do Protocolo

**1. ANNOUNCE_LIQUIDITY**

Peer anuncia liquidez disponível para swaps.

```json
{
  "type": "announce_liquidity",
  "peer_id": "03abc123...",
  "timestamp": 1705320000,
  "liquidity": [
    {
      "asset": "lbtc",
      "amount_sats": 10000000,
      "swap_types": ["LBTC_TO_LIGHTNING", "LBTC_TO_BTC"],
      "fee_ppm": 500
    },
    {
      "asset": "btc",
      "amount_sats": 5000000,
      "swap_types": ["BTC_TO_LIGHTNING", "BTC_TO_LBTC"],
      "fee_ppm": 1000
    }
  ],
  "ttl": 10,
  "signature": "3045022100..."
}
```

**Campos:**
- `peer_id`: Lightning pubkey do anunciante
- `liquidity`: Lista de assets e quantidades disponíveis
- `fee_ppm`: Taxa em parts per million (500 = 0.05%)
- `ttl`: Time-to-live em hops (decrementado a cada retransmissão)
- `signature`: Assinatura da mensagem (prova de autenticidade)

---

**2. REQUEST_SWAP**

Initiator solicita swap com peer específico.

```json
{
  "type": "request_swap",
  "swap_id": "uuid-123",
  "initiator_peer_id": "03alice...",
  "receiver_peer_id": "03bob...",
  "swap_type": "LBTC_TO_LIGHTNING",
  "amount_sats": 1000000,
  "payment_hash": "7f3e9a...",
  "timeout_blocks": 288,
  "fee_sats": 5000,
  "timestamp": 1705320000,
  "signature": "3045022100..."
}
```

---

**3. ACCEPT_SWAP / REJECT_SWAP**

Receiver aceita ou rejeita swap request.

```json
{
  "type": "accept_swap",
  "swap_id": "uuid-123",
  "receiver_peer_id": "03bob...",
  "htlc_address": "ex1q...",
  "lightning_invoice": "lnbc1m...",
  "timestamp": 1705320010,
  "signature": "3045022100..."
}
```

ou

```json
{
  "type": "reject_swap",
  "swap_id": "uuid-123",
  "reason": "insufficient_liquidity",
  "timestamp": 1705320010,
  "signature": "3045022100..."
}
```

---

**4. SWAP_STATUS_UPDATE**

Atualizações sobre progresso do swap.

```json
{
  "type": "swap_status_update",
  "swap_id": "uuid-123",
  "state": "FUNDED",
  "funding_txid": "abc123...",
  "confirmations": 2,
  "timestamp": 1705320100,
  "signature": "3045022100..."
}
```

---

### Propagação de Mensagens

**Flood-Fill com TTL:**

```python
def propagate_message(message: dict, sender_peer_id: str):
    """
    Propaga mensagem para rede P2P.
    """
    # 1. Verificar TTL
    if message.get('ttl', 0) <= 0:
        return  # Não propagar mais

    # 2. Verificar se já vimos esta mensagem (evita loops)
    message_hash = hash_message(message)
    if message_hash in seen_messages:
        return

    seen_messages.add(message_hash)

    # 3. Decrementar TTL
    message['ttl'] -= 1

    # 4. Enviar para todos os peers exceto sender
    for peer in get_all_active_peers():
        if peer.peer_pubkey == sender_peer_id:
            continue  # Não enviar de volta para sender

        try:
            send_message_to_peer(peer.id, message)
        except Exception as e:
            logger.warning(f"Failed to propagate to {peer.peer_alias}: {e}")
```

**Cache de Mensagens Vistas:**

```python
# LRU cache de 10,000 mensagens
from functools import lru_cache

@lru_cache(maxsize=10000)
def hash_message(message: dict) -> str:
    """
    Calcula hash único da mensagem para deduplicação.
    """
    import json
    import hashlib

    # Remover campos que variam (ttl, timestamp de propagação)
    msg_copy = message.copy()
    msg_copy.pop('ttl', None)

    msg_json = json.dumps(msg_copy, sort_keys=True)
    return hashlib.sha256(msg_json.encode()).hexdigest()
```

---

## 5.4 Coordenação de Swap P2P

### Protocolo de Handshake Completo

**Atores:**
- **Alice** (Initiator): Tem L-BTC, quer Lightning
- **Bob** (Responder): Tem Lightning, quer L-BTC

**11 Passos:**

```
Alice                                    Bob
  │                                       │
  ├─1. Descobre Bob via gossip ──────────┤
  │   (ANNOUNCE_LIQUIDITY)               │
  │                                       │
  ├─2. Gera preimage ─────────────────────┤
  │   preimage = random(32 bytes)        │
  │   payment_hash = SHA256(preimage)    │
  │                                       │
  ├─3. REQUEST_SWAP ─────────────────────>│
  │   {swap_id, payment_hash, amount}    │
  │                                       │
  │                                       ├─4. Valida request
  │                                       │   • Liquidez suficiente?
  │                                       │   • Taxa aceitável?
  │                                       │   • Reputação de Alice OK?
  │                                       │
  │<───────────── 5. ACCEPT_SWAP ────────┤
  │   {swap_id, htlc_address}            │
  │                                       │
  ├─6. Funding TX (L-BTC) ───────────────>│
  │   Envia para htlc_address            │
  │                                       │
  │   ...aguarda 2 confirmações...       │
  │                                       │
  ├─7. SWAP_STATUS_UPDATE ───────────────>│
  │   {state: FUNDED, txid, confs: 2}    │
  │                                       │
  │                                       ├─8. Verifica funding TX
  │                                       │   • HTLC correto?
  │                                       │   • Valor correto?
  │                                       │
  │                                       ├─9. Cria Lightning invoice
  │                                       │   invoice = add_invoice(
  │                                       │     payment_hash, 1M sats
  │                                       │   )
  │                                       │
  │<──────── 10. Lightning invoice ──────┤
  │   {payment_request: lnbc1m...}       │
  │                                       │
  ├─11. Paga invoice Lightning ──────────>│
  │   lnd.send_payment(invoice)          │
  │   (revela preimage)                  │
  │                                       │
  │                                       ├─12. Recebe pagamento
  │                                       │    Extrai preimage
  │                                       │
  │                                       ├─13. Claim L-BTC
  │                                       │    TX gasta HTLC c/preimage
  │                                       │
  │<────── 14. SWAP_COMPLETE ────────────┤
  │   {state: CLAIMED, claim_txid}       │
  │                                       │
  └───────────── ✅ SUCESSO ──────────────┘
```

**Arquivo:** `/root/brln-os/api/network/p2p_swap_coordinator.py` (TODO)

---

### Envio de Mensagens

**Via Lightning (Keysend):**

```python
def send_message_via_lightning(peer_pubkey: str, message: dict):
    """
    Envia mensagem via Lightning keysend.
    """
    import json

    # Serializar mensagem
    message_json = json.dumps(message)
    message_bytes = message_json.encode()

    # Enviar via keysend com custom record
    lnd_client.send_payment_v2(
        dest_pubkey=peer_pubkey,
        amt_msat=1000,  # 1 sat (taxa mínima)
        custom_records={
            5482373484: message_bytes  # Record type para BRLN messages
        }
    )
```

**Via Tor:**

```python
def send_message_via_tor(peer_onion: str, message: dict):
    """
    Envia mensagem via Tor hidden service.
    """
    import requests
    import json

    # SOCKS5 proxy para Tor
    proxies = {
        'http': 'socks5h://127.0.0.1:9050',
        'https': 'socks5h://127.0.0.1:9050'
    }

    # POST para endpoint HTTP do peer
    response = requests.post(
        f'http://{peer_onion}/api/v1/p2p/message',
        json=message,
        proxies=proxies,
        timeout=30
    )

    return response.json()
```

---

## 5.5 Reputação e Anti-Fraude

### Sistema de Pontuação

**Cálculo de Reputação:**

```python
def calculate_reputation(peer: Peer) -> int:
    """
    Calcula score de reputação (0-100+).
    """
    base_score = 100

    # Bônus por swaps bem-sucedidos
    success_bonus = peer.successful_swaps * 10

    # Penalidade por swaps falhados
    failure_penalty = peer.failed_swaps * 5

    # Penalidade por timeouts (swaps expirados)
    timeout_penalty = peer.timeout_swaps * 2

    # Score final
    score = base_score + success_bonus - failure_penalty - timeout_penalty

    # Limitar entre 0 e 200
    return max(0, min(200, score))
```

**Atualização Após Swap:**

```python
def update_peer_reputation_after_swap(peer_id: str,
                                        swap_state: SwapState):
    """
    Atualiza reputação após conclusão de swap.
    """
    peer = get_peer(peer_id)

    if swap_state == SwapState.CLAIMED:
        # Swap sucesso
        peer.successful_swaps += 1
        peer.reputation_score += 10

    elif swap_state == SwapState.FAILED:
        # Swap falhou (culpa do peer)
        peer.failed_swaps += 1
        peer.reputation_score -= 5

    elif swap_state == SwapState.REFUNDED:
        # Swap expirou (timeout)
        peer.timeout_swaps += 1
        peer.reputation_score -= 2

    # Recalcular score completo
    peer.reputation_score = calculate_reputation(peer)

    session.commit()
```

---

### Blacklist Automática

**Regras:**

```python
def check_peer_blacklist_status(peer: Peer) -> tuple[bool, str]:
    """
    Verifica se peer deve ser bloqueado.

    Returns:
        (is_blacklisted, reason)
    """
    # Regra 1: Score negativo
    if peer.reputation_score < 0:
        return (True, "Reputation score negative")

    # Regra 2: 3 falhas consecutivas
    if peer.consecutive_failures >= 3:
        return (True, "3 consecutive failed swaps")

    # Regra 3: Taxa de falha > 50%
    total_swaps = peer.successful_swaps + peer.failed_swaps
    if total_swaps > 10:  # Mínimo 10 swaps
        failure_rate = peer.failed_swaps / total_swaps
        if failure_rate > 0.5:
            return (True, f"Failure rate {failure_rate:.0%} > 50%")

    # Regra 4: Offline por mais de 30 dias
    if peer.last_seen_at < datetime.utcnow() - timedelta(days=30):
        return (True, "Offline for 30+ days")

    return (False, "")

def enforce_blacklist():
    """
    Marca peers blacklisted como inativos.
    """
    for peer in get_all_peers():
        is_blacklisted, reason = check_peer_blacklist_status(peer)

        if is_blacklisted:
            peer.is_active = False
            logger.warning(f"Blacklisted peer {peer.peer_alias}: {reason}")

            # Criar evento de blacklist
            create_peer_event(
                peer_id=peer.id,
                event_type="BLACKLISTED",
                details={'reason': reason}
            )

    session.commit()
```

**Desbloqueio Temporário:**

Peer pode ser desbloqueado após período de "quarentena":

```python
def unblacklist_peer_after_quarantine(peer_id: str):
    """
    Desbloqueia peer após 7 dias de quarentena.
    """
    peer = get_peer(peer_id)

    # Verificar se passou 7 dias desde último evento de blacklist
    last_blacklist = get_last_peer_event(peer_id, "BLACKLISTED")
    if last_blacklist and \
       last_blacklist.created_at < datetime.utcnow() - timedelta(days=7):

        # Reset score para 50 (neutro)
        peer.reputation_score = 50
        peer.is_active = True
        peer.consecutive_failures = 0

        logger.info(f"Unblacklisted peer {peer.peer_alias} after quarantine")
        session.commit()
```

---

# 6. Database: Persistência e Gerenciamento

O BRLN-OS utiliza um sistema robusto de persistência baseado em **SQLAlchemy ORM** com suporte para PostgreSQL (produção) e SQLite (desenvolvimento).

## 6.1 Schema Completo

### Tabela: `swaps`

**Função:** Rastreamento completo do ciclo de vida de atomic swaps.

**Arquivo:** `/root/brln-os/api/persistence/models.py`

**Estrutura:**

```python
class Swap(Base):
    __tablename__ = 'swaps'

    # Identificação
    id = Column(UUID, primary_key=True)                    # UUID único
    swap_type = Column(Enum(SwapDirection), nullable=False) # Tipo de swap
    state = Column(Enum(SwapState), nullable=False)         # Estado atual

    # HTLC
    payment_hash = Column(String(64), unique=True, nullable=False)  # 32 bytes hex
    preimage = Column(String(64), nullable=True)                    # Encrypted, deletado após conclusão
    timeout_block_height = Column(Integer, nullable=False)
    network_type = Column(Enum(NetworkType), nullable=False)

    # Partes
    initiator_peer_id = Column(UUID, ForeignKey('peers.id'))
    receiver_peer_id = Column(UUID, ForeignKey('peers.id'))

    # Quantias
    amount_satoshis = Column(BigInteger, nullable=False)
    fee_satoshis = Column(BigInteger, default=0)

    # Transações
    funding_txid = Column(String(64), nullable=True)
    funding_vout = Column(Integer, nullable=True)
    claim_txid = Column(String(64), nullable=True)
    refund_txid = Column(String(64), nullable=True)

    # Script HTLC
    htlc_script_hex = Column(Text, nullable=False)
    htlc_address = Column(String(128), nullable=False)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    funded_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    expires_at = Column(DateTime, nullable=False)

    # Recovery
    recovery_file_path = Column(String(512), nullable=True)

    # Lightning (se aplicável)
    lightning_invoice = Column(Text, nullable=True)
    lightning_payment_request = Column(Text, nullable=True)

    # Relações
    initiator = relationship("Peer", foreign_keys=[initiator_peer_id])
    receiver = relationship("Peer", foreign_keys=[receiver_peer_id])
    transactions = relationship("SwapTransaction", back_populates="swap")
    events = relationship("SwapEvent", back_populates="swap")
```

**Estados Possíveis:**

| Estado | Descrição | Próxima Ação |
|--------|-----------|--------------|
| INITIATED | Swap criado, preimage gerado | Funding TX |
| FUNDED | HTLC funded on-chain | Claim ou timeout |
| CLAIMED | Preimage revelado, fundos claimed | Completo ✅ |
| EXPIRED | Timeout passou, sem claim | Refund TX |
| REFUNDED | Fundos devolvidos após timeout | Completo ♻️ |
| FAILED | Erro irrecuperável | Investigar ❌ |

---

Todas as demais tabelas (`peers`, `swap_transactions`, `swap_events`, `assets`) seguem estruturas detalhadas em `/root/brln-os/api/persistence/models.py`.

**Migrações Alembic** gerenciam evolução do schema em `/root/brln-os/api/persistence/migrations/`.

**Connection Pooling** configurado para PostgreSQL (produção) e SQLite (desenvolvimento) em `/root/brln-os/api/persistence/database.py`.

---

# 7. Integrações Externas

## 7.1 Boltz Backend

**O que é:** Provedor de liquidez para submarine swaps (BTC/L-BTC ↔ Lightning).

**Uso:** Fallback quando não há peer P2P disponível.

**Arquivo:** `/root/brln-os/api/external/boltz_client.py` e `/root/brln-os/scripts/install-boltz-backend.sh`

## 7.2 PeerSwap

**O que é:** Plugin LND para rebalanceamento de canais via Liquid.

**Uso:** Complementar ao sistema nativo BRLN-OS para gestão de liquidez.

**Arquivo:** `/root/brln-os/scripts/peerswap.sh`

## 7.3 Lightning Chat (Keysend)

**Uso:** Comunicação P2P entre nodes BRLN-OS via Lightning custom TLV records.

**Monitoramento:** `services/messager-monitor.service`

---

# 8. Stack Tecnológica

## 8.1 Linguagens

- **Python 3.12:** API Flask, swap orchestration
- **Bash:** Scripts instalação/manutenção
- **JavaScript Vanilla:** Frontend
- **HTML5/CSS3:** Interface

## 8.2 Frameworks & Bibliotecas

```python
# /root/brln-os/api/v1/requirements.txt
flask==3.0.0
grpcio==1.60.0
sqlalchemy==2.0.25
alembic==1.13.1
cryptography==41.0.7
mnemonic==0.21
bip32==4.0
requests==2.31.0
```

## 8.3 Infraestrutura

- **systemd:** Gerenciamento de serviços
- **Apache 2.4:** Web server + reverse proxy
- **PostgreSQL/SQLite:** Database
- **Tor:** Privacidade de rede

## 8.4 Dependências de Sistema

- Bitcoin Core 29.2
- LND 0.20.0
- Elements 24.0
- Node.js v20.x (para LNbits, ThunderHub)

---

# 9. Fluxos Completos End-to-End

## 9.1 Instalação

```bash
sudo su
git clone https://github.com/pagcoinbr/brln-os.git && cd brln-os && bash brunel.sh
```

**Passos Automáticos:** Instala Bitcoin Core, LND, Elements, API, frontend, configura systemd, gera master password.

## 9.2 Criar Wallet HD

**Frontend** → POST `/api/v1/wallet/generate` → **Backend** gera BIP39 → Exibe 24 palavras → Usuário salva → POST `/api/v1/wallet/save` (criptografado com master password).

## 9.3 Submarine Swap L-BTC → Lightning (Exemplo Completo)

**Alice (tem 0.01 L-BTC) quer 1M sats Lightning:**

1. Alice gera preimage, calcula payment_hash
2. Alice cria HTLC Liquid, envia L-BTC
3. Bob cria Lightning invoice com mesmo payment_hash
4. Alice paga invoice (Lightning revela preimage)
5. Bob extrai preimage, reclama L-BTC
6. **Swap completo!** Alice tem Lightning ⚡, Bob tem L-BTC 💧

**Timeline:** ~10-15 minutos

**Código:** `/root/brln-os/api/core/liquid_submarine_swap.py` (TODO)

## 9.4 Recuperação de Swap Falhado

**Cenário:** Timeout expira sem claim.

**Ação:** Alice (ou sistema automático) broadcast refund TX gastando HTLC com timeout path.

**Recovery File:** JSON criptografado com preimage, script HTLC, chaves de refund.

---

# 10. Segurança

## 10.1 Threat Model

**Ameaças Principais:**
1. Roubo de seeds → **Mitigado:** Criptografia PBKDF2 + AES-256-GCM
2. Session hijacking → **Mitigado:** HTTP-only, Secure, SameSite cookies
3. Preimage leak → **Mitigado:** Encrypted at rest, deletado após swap
4. Timeout manipulation → **Mitigado:** Safety margins (6 blocos Bitcoin, 2 blocos Liquid)
5. P2P Sybil attacks → **Mitigado:** Sistema de reputação, blacklist automática

## 10.2 Criptografia

**Master Password:**
- PBKDF2 (600k iterações) + Fernet (AES-128-CBC + HMAC-SHA256)
- Seeds, preimages, recovery files todos criptografados

**Session:**
- 5 minutos TTL, renovado a cada request
- UUID session_id, armazenado em Redis ou memória

## 10.3 Hardening

```bash
# Firewall
sudo ufw default deny incoming
sudo ufw allow 443/tcp  # HTTPS only

# systemd
PrivateTmp=true
NoNewPrivileges=true
ProtectSystem=strict

# Tor only mode
bitcoin.conf: onlynet=onion
lnd.conf: tor.active=true
```

**Arquivo:** `/root/brln-os/api/v1/SECURITY_ARCHITECTURE.md`

---

# 11. Deployment e Operação

## 11.1 Requisitos

- Ubuntu Server 24.04 LTS
- 16 GB RAM (recomendado)
- 1 TB SSD
- Conexão estável

## 11.2 Manutenção

```bash
# Deploy frontend
bash scripts/maintenance.sh deploy

# Restart API
bash scripts/maintenance.sh api

# Check services
bash scripts/maintenance.sh check

# Force HTTPS
bash scripts/maintenance.sh ssl-only
```

## 11.3 Backup

**Crítico:**
- Master password (físico, papel)
- Database: `pg_dump brln_swaps > backup.sql`
- LND SCB: `~/lnd/.lnd/data/chain/bitcoin/mainnet/channel.backup`
- Wallets: `~/.brln/wallet_backups/`

## 11.4 Troubleshooting

**LND não inicia:** `journalctl -u lnd -n 100` → Wallet locked? `lncli unlock`

**Swap travado:** Check timeout → Force refund `POST /api/v1/swaps/{swap_id}/refund`

**Out of disk:** Enable pruning `prune=50000` em `bitcoin.conf`

---

# 12. Roadmap e Futuro

## Status Atual (Janeiro 2026): 40% Implementado

**✅ Completo:**
- Database layer (Swap, Peer, Transaction, Event)
- HTLC script builder
- LND gRPC client extended
- Invoice manager

**⏳ Em Progresso:**
- Liquid RPC client
- Swap orchestrator (L-BTC ↔ Lightning)

## Fase 1 (Q1 2026): Core MVP

- Liquid integration completa
- L-BTC ↔ Lightning submarine swaps
- API endpoints `/api/v1/swaps/*`
- Testes em testnet

## Fase 2 (Q2 2026): P2P Network

- Gossip protocol via Tor
- Peer discovery automated
- Reputation system ativo

## Fase 3 (Q2-Q3 2026): Mainnet Launch

- Security audit profissional
- Mainnet deployment
- Community liquidity bootstrap

## Fase 4 (Q3-Q4 2026): Advanced Features

- Cross-chain swaps (BTC ↔ ETH)
- Taproot Assets support
- Mobile companion app
- Hardware wallet integration

**Visão de Longo Prazo:** BRLN-OS como protocol interoperável com Boltz, Loop, PeerSwap. Lightning LSP built-in, stablecoin swaps via Liquid.

---

# 13. Apêndices

## Apêndice A: Glossário Técnico

- **HTLC:** Hash Time Lock Contract
- **Preimage:** Secreto de 32 bytes, SHA256(preimage) = payment_hash
- **Payment Hash:** Hash público do preimage
- **Submarine Swap:** L-BTC/BTC → Lightning
- **Reverse Submarine:** Lightning → L-BTC/BTC
- **Atomic:** Ou completa 100% ou nada acontece
- **Trustless:** Sem necessidade de confiar em terceiros
- **P2WSH:** Pay to Witness Script Hash (SegWit)
- **BIP32/39/44:** Bitcoin Improvement Proposals para HD wallets

## Apêndice B: Referências

- **Bitcoin BIPs:** 32, 39, 44, 68, 112, 141, 340
- **Lightning BOLT specs:** 1-11
- **Elements Project:** https://elementsproject.org
- **LND Documentation:** https://docs.lightning.engineering
- **Boltz Backend:** https://docs.boltz.exchange

## Apêndice C: Código de Exemplo

**Criar HTLC:**

```python
from api.core.scriptbuilder import build_htlc_script
from api.core.preimage import generate_preimage
import hashlib

preimage = generate_preimage()
payment_hash = hashlib.sha256(preimage).digest()

htlc_script = build_htlc_script(
    payment_hash=payment_hash,
    receiver_pubkey=bob_pubkey,
    sender_pubkey=alice_pubkey,
    timeout_blocks=288
)
```

**Criar Invoice com Payment Hash:**

```python
from api.lnd.invoice_manager import get_invoice_manager

manager = get_invoice_manager()
invoice = manager.create_swap_invoice(
    amount_sats=1000000,
    payment_hash=payment_hash,
    expiry_seconds=3600
)
```

## Apêndice D: FAQ Técnico

**Q: Por que usar Liquid ao invés de Bitcoin direto?**
A: Blocos de 1 minuto (vs 10 min), transações confidenciais, multi-asset support.

**Q: Atomic swaps são seguros mesmo sem confiar no peer?**
A: Sim! HTLC garante atomicidade matemática. Ou ambos recebem ou ninguém perde fundos.

**Q: O que acontece se meu node ficar offline durante swap?**
A: Recovery files permitem reembolso após timeout. Fundos nunca são perdidos.

**Q: Posso rodar BRLN-OS em mainnet agora?**
A: Fase MVP ainda em desenvolvimento. Recomendamos testnet até Q2-Q3 2026.

**Q: Como contribuir com o projeto?**
A: GitHub Issues, Pull Requests, Telegram: https://t.me/pagcoinbr

---

**FIM DO DOCUMENTO**

Este documento técnico descreve a arquitetura completa do BRLN-OS, sistema operacional para auto-custódia Bitcoin com atomic swaps descentralizados. Para mais informações, consulte o repositório oficial: https://github.com/pagcoinbr/brln-os

**Versão:** 1.0
**Data:** Janeiro 2026
**Licença:** MIT
**Autor:** Comunidade BRLN

