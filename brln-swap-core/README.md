# BRLN-OS Atomic Swap Module

**P2P Decentralized Swap System for Bitcoin, Lightning Network and Liquid Assets**

> Protótipo pré-MVP - Python only implementation

---

## Overview

O **BRLN-OS Atomic Swap Module** transforma o BRLN-OS em uma super wallet P2P com capacidades de swap atômico descentralizado. Permite trocar ativos entre Bitcoin on-chain, Lightning Network e Liquid Network de forma trustless, permissionless e completamente segura através de **Hash Time Locked Contracts (HTLC)**.

### Key Features

- **Atomic Swaps** - Swaps trustless garantidos por HTLC
- **Multi-Asset** - Bitcoin on-chain, Lightning, L-BTC e Liquid Assets
- **P2P Network** - Descoberta de peers via Tor hidden services
- **Gossip Protocol** - Comunicação descentralizada entre peers
- **Self-Custodial** - Controle total sobre suas chaves privadas
- **Submarine Swaps** - Troca on-chain ↔ Lightning
- **Recovery System** - Recuperação automática de fundos em caso de falha
- **Open Source** - Totalmente auditável e extensível

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   BRLN-OS Swap Module                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  REST API   │  │  CLI Tool    │  │  Web UI      │     │
│  └──────┬──────┘  └──────┬───────┘  └──────┬───────┘     │
│         │                 │                  │             │
│         └─────────────────┴──────────────────┘             │
│                           │                                │
│         ┌─────────────────┴──────────────────┐            │
│         │   Atomic Swap Orchestrator         │            │
│         │  (atomicswap.py, submarineswap.py) │            │
│         └─────────────────┬──────────────────┘            │
│                           │                                │
│    ┌──────────────────────┼──────────────────────┐        │
│    │                      │                       │        │
│ ┌──▼────┐          ┌─────▼──────┐         ┌─────▼────┐   │
│ │ HTLC  │          │  P2P       │         │ Persist  │   │
│ │Builder│          │  Network   │         │ ence     │   │
│ └───┬───┘          └──────┬─────┘         └─────┬────┘   │
│     │                     │                      │        │
│     │  ┌──────────────────┼──────────────────────┘        │
│     │  │                  │                               │
├─────┼──┼──────────────────┼───────────────────────────────┤
│     │  │                  │    Integration Layer          │
├─────▼──▼──────────────────▼───────────────────────────────┤
│                                                             │
│  ┌──────────┐  ┌───────────────┐  ┌─────────────────┐    │
│  │   LND    │  │   elementsd   │  │   PostgreSQL    │    │
│  │  (gRPC)  │  │   (RPC JSON)  │  │   + Redis       │    │
│  └──────────┘  └───────────────┘  └─────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
  ┌────────────┐      ┌─────────────┐     ┌─────────────┐
  │  Bitcoin   │      │   Liquid    │     │  Lightning  │
  │ Blockchain │      │ Blockchain  │     │   Network   │
  └────────────┘      └─────────────┘     └─────────────┘
```

### Core Components

#### 1. **Core Module** (`brln-swap-core/core/`)
- `preimage.py` - Geração de preimage (32 bytes) e hash SHA256
- `scriptbuilder.py` - Construção de scripts HTLC para Bitcoin/Liquid
- `htlc.py` - Lógica HTLC com OP_CHECKSEQUENCEVERIFY
- `txbuilder.py` - Construção, assinatura e broadcast de transações
- `atomicswap.py` - Orquestração completa de atomic swap
- `submarineswap.py` - Swaps on-chain ↔ Lightning
- `liquidswap.py` - Swaps envolvendo ativos Liquid
- `recovery.py` - Sistema de recuperação de fundos

#### 2. **LND Integration** (`brln-swap-core/lnd/`)
- `lndclient.py` - Wrapper gRPC para LND
- `invoicemanager.py` - Gerenciamento de invoices Lightning
- `channelmanager.py` - Gerenciamento de canais
- `paymentmonitor.py` - Monitoramento de pagamentos

#### 3. **Liquid Integration** (`brln-swap-core/liquid/`)
- `liquidclient.py` - Wrapper RPC para elementsd
- `assetmanager.py` - Gerenciamento de ativos Liquid
- `transactionmanager.py` - Ciclo de vida de transações
- `confirmationmonitor.py` - Monitoramento de confirmações

#### 4. **P2P Network** (`brln-swap-core/network/`)
- `p2pprotocol.py` - Protocolo gossip customizado
- `discovery.py` - Descoberta de peers via Tor
- `messaging.py` - Serialização e transmissão de mensagens
- `torclient.py` - Integração com Tor
- `peermanager.py` - Gerenciamento de peers ativos

#### 5. **Persistence** (`brln-swap-core/persistence/`)
- `models.py` - SQLAlchemy models (swaps, peers, ativos)
- `database.py` - Pool de conexões e operações
- `migrations/` - Alembic database migrations

#### 6. **API** (`brln-swap-core/api/`)
- `schemas.py` - Pydantic schemas para validação
- Integração com Flask API existente (`api/v1/app.py`)

#### 7. **CLI** (`brln-swap-core/cli/`)
- `cli.py` - Interface de linha de comando (Click)

---

## How Atomic Swaps Work

### Example: Bitcoin on-chain ↔ Lightning Submarine Swap

```
Peer A (has BTC on-chain)  ←→  Peer B (wants BTC on-chain, has Lightning)

┌──────────────────────────────────────────────────────────────────────┐
│ Phase 1: Initiation                                                  │
├──────────────────────────────────────────────────────────────────────┤
│ 1. Peer A generates random 32-byte preimage                         │
│ 2. Peer A calculates hash = SHA256(preimage)                        │
│ 3. Peer A creates HTLC script:                                       │
│    "Pay to Peer B if: (signature + preimage) OR                     │
│     Pay to Peer A if: (signature + timeout expired)"                │
│ 4. Peer A broadcasts transaction locking BTC in HTLC                │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│ Phase 2: Lock Funds                                                  │
├──────────────────────────────────────────────────────────────────────┤
│ 5. Peer B verifies HTLC on Bitcoin blockchain                       │
│ 6. Peer B creates Lightning invoice with payment_hash = hash        │
│ 7. Peer A pays invoice via Lightning Network                        │
│ 8. Lightning network forces Peer B to reveal preimage to claim ⚡   │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│ Phase 3: Claim                                                        │
├──────────────────────────────────────────────────────────────────────┤
│ 9. Peer A observes preimage revealed on Lightning Network           │
│ 10. Peer B uses preimage to claim BTC from HTLC on-chain           │
│ ✓ Swap complete atomically!                                         │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│ Phase 4: Recovery (if something fails)                               │
├──────────────────────────────────────────────────────────────────────┤
│ - If Peer B never claims, timeout expires (144 blocks ~24h)         │
│ - Peer A recovers original BTC using timeout clause                 │
│ - Recovery file stores all necessary data for refund                │
└──────────────────────────────────────────────────────────────────────┘
```

### Security Properties

1. **Atomicity** - Either both sides get their assets or neither does
2. **Trustless** - No need to trust counterparty or intermediary
3. **Timeout Protection** - Funds auto-recover after timeout
4. **Preimage Secrecy** - Only initiator knows preimage initially
5. **Blockchain Security** - Enforced by Bitcoin/Lightning consensus

---

## Installation

### Prerequisites

- BRLN-OS fully installed and running
- LND operational with channels
- elementsd operational
- Python 3.10+
- PostgreSQL 16+ or SQLite (dev)
- Redis 7+
- Tor service running

### Quick Start

```bash
# 1. Clone or navigate to BRLN-OS directory
cd /root/brln-os/brln-swap-core

# 2. Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Copy environment template
cp .env.example .env
nano .env  # Edit with your configuration

# 5. Start database services
docker-compose up -d

# 6. Initialize database
alembic upgrade head

# 7. Test the installation
python -m pytest tests/

# 8. Start swap service
python -m brln_swap_core.api.fastapi_app
```

---

## Usage

### Via CLI

```bash
# Initiate a swap
brln-swap initiate \
  --peer abcdef1234.onion:9735 \
  --amount 100000 \
  --from btc \
  --to lightning

# Check swap status
brln-swap status <swap_id>

# List all active swaps
brln-swap list --status active

# List peers
brln-swap peers list

# Add new peer
brln-swap peers add --address xyz789.onion:9735

# Recover stuck swap
brln-swap recover <swap_id>
```

### Via API

```bash
# Initiate swap
curl -X POST http://localhost:2122/api/v1/swaps/initiate \
  -H "Content-Type: application/json" \
  -d '{
    "peer_id": "abcdef1234.onion:9735",
    "amount_sats": 100000,
    "from_asset": "btc",
    "to_asset": "lightning"
  }'

# Get swap status
curl http://localhost:2122/api/v1/swaps/status/swap_uuid_here

# List swaps
curl http://localhost:2122/api/v1/swaps/list

# List peers
curl http://localhost:2122/api/v1/peers/list
```

### Via Python

```python
from brln_swap_core.core.atomicswap import AtomicSwapManager
from brln_swap_core.lnd.lndclient import LNDClient
from brln_swap_core.liquid.liquidclient import LiquidClient

# Initialize clients
lnd_client = LNDClient()
liquid_client = LiquidClient()

# Create swap manager
swap_manager = AtomicSwapManager(lnd_client, liquid_client)

# Initiate swap
swap_id = swap_manager.initiate_swap(
    peer_address="abcdef.onion:9735",
    amount_sats=100000,
    from_asset="btc",
    to_asset="lightning"
)

# Monitor swap
status = swap_manager.get_swap_status(swap_id)
print(f"Swap status: {status}")
```

---

## Configuration

### Environment Variables

See `.env.example` for complete list of configuration options.

Key configurations:
- `BITCOIN_NETWORK` - mainnet, testnet, signet, regtest
- `DATABASE_URL` - PostgreSQL connection string
- `LND_*` - LND gRPC connection settings
- `ELEMENTS_*` - Elements/Liquid RPC settings
- `TOR_*` - Tor network configuration
- `MAX_SWAP_AMOUNT_SATS` - Maximum swap amount (safety limit)

### Swap Timeouts

```python
# Bitcoin (144 blocks ≈ 24 hours)
BITCOIN_SWAP_TIMEOUT = 144

# Liquid (288 blocks ≈ 24 hours, 2.5x faster than Bitcoin)
LIQUID_SWAP_TIMEOUT = 288

# Confirmation requirements (account for reorgs)
BITCOIN_MIN_CONFIRMATIONS = 6
LIQUID_MIN_CONFIRMATIONS = 2
```

---

## Security

### Critical Security Considerations

1. **Private Keys** - Never exposed outside secure modules
2. **Constant-Time Comparisons** - Used for all secret comparisons
3. **Recovery Files** - Stored with 0600 permissions, encrypted
4. **Database Encryption** - At-rest encryption for sensitive data
5. **Timeout Margins** - Account for blockchain reorganizations
6. **Input Validation** - All inputs validated with Pydantic
7. **Tor Anonymity** - All P2P communication via Tor

### Security Best Practices

- Run on testnet first
- Limit swap amounts during prototype phase
- Backup recovery files immediately after swap initiation
- Monitor logs for suspicious activity
- Use strong master password
- Keep LND and elementsd updated
- Regular security audits before mainnet deployment

---

## Testing

### Unit Tests

```bash
# Run all tests
pytest tests/

# Run specific module tests
pytest tests/unit/test_preimage.py
pytest tests/unit/test_htlc.py

# Run with coverage
pytest --cov=brln_swap_core tests/
```

### Integration Tests

```bash
# Requires running LND and elementsd on testnet
pytest tests/integration/

# Test specific swap type
pytest tests/integration/test_submarine_swap.py
```

---

## Roadmap

### Phase 1: Foundation (Current - Prototype)
- [x] Project structure
- [x] Database schema
- [x] Core HTLC implementation
- [ ] LND integration
- [ ] Liquid integration
- [ ] Basic CLI

### Phase 2: P2P Network
- [ ] Gossip protocol
- [ ] Tor integration
- [ ] Peer discovery
- [ ] Message encryption

### Phase 3: Swap Types
- [ ] Bitcoin on-chain ↔ Bitcoin on-chain
- [ ] Submarine swaps (on-chain ↔ Lightning)
- [ ] Liquid swaps (L-BTC, Liquid Assets)

### Phase 4: Production Ready
- [ ] Comprehensive testing
- [ ] Security audit
- [ ] Documentation
- [ ] Performance optimization
- [ ] Mainnet deployment

---

## Contributing

This is a prototype implementation. Contributions welcome!

### Development Setup

```bash
# Install dev dependencies
pip install -r requirements.txt
pip install black pylint mypy pytest-cov

# Format code
black brln_swap_core/

# Lint
pylint brln_swap_core/

# Type check
mypy brln_swap_core/
```

---

## License

Same license as BRLN-OS (check main repository).

---

## Support

- Documentation: See `.docs/` directory
- Issues: File on BRLN-OS GitHub repository
- Community: Join BRLN-OS community channels

---

## Acknowledgments

Based on research and specifications from:
- Lightning Network BOLT specifications
- Bitcoin BIP119 (OP_CHECKSEQUENCEVERIFY)
- Blockstream Liquid Network documentation
- Submarine Swap protocols (Lightning Labs, Boltz)
- Academic papers on atomic swaps and HTLCs

---

**⚠️ PROTOTYPE WARNING**: This is a pre-MVP prototype. Do NOT use with significant amounts on mainnet without thorough security audit and extensive testing.
