# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BRLN-OS is a complete self-hosted node distribution that transforms Ubuntu 24.04 LTS servers into sovereign Bitcoin + Lightning + Liquid nodes. It provides:
- Bitcoin Core + LND + Elements/Liquid integration
- Flask API (gRPC bridge to LND) with session-based auth
- Static HTML/CSS/JS frontend served via Apache
- systemd service management
- Master password encryption (Fernet/PBKDF2)

## Common Commands

### Installation
```bash
git clone https://github.com/pagcoinbr/brln-os.git && cd brln-os && bash brunel.sh
```

### Maintenance & Deployment
```bash
bash scripts/maintenance.sh deploy      # Deploy frontend to /var/www/html
bash scripts/maintenance.sh api         # Restart API services
bash scripts/maintenance.sh check       # Verify all services status
bash scripts/maintenance.sh ssl-only    # Configure HTTPS-only access
```

### API Development
```bash
# Setup API virtual environment
bash scripts/setup-api-env.sh

# Activate venv (production path)
source /home/brln-api/venv/bin/activate

# Install dependencies
pip install -r api/v1/requirements.txt

# Regenerate gRPC stubs after proto changes
bash scripts/gen-proto.sh
bash scripts/gen-proto.sh --force-download  # Force re-download protos
```

### Service Management
```bash
sudo systemctl restart brln-api           # Main API service
sudo systemctl restart messager-monitor   # Lightning chat monitor
sudo systemctl status bitcoind lnd brln-api
```

### Health Check
```bash
curl http://localhost:2121/api/v1/system/health
```

## Architecture

### Layer Structure
```
Frontend (pages/)          -> Apache (:443) -> Static HTML/CSS/JS
API (api/v1/app.py)        -> Flask (:2121) -> gRPC -> LND/Bitcoin/Elements
Scripts (scripts/)         -> Bash orchestration & systemd service generation
Config Templates (conf_files/) -> bitcoin.conf, lnd.conf, Apache configs
```

### Key Directories
- `api/v1/` - Flask API entrypoint (`app.py`), gRPC stubs (`*_pb2.py`), proto files in `proto/`
- `pages/` - Frontend with iframe-based navigation; `components/` contains per-feature UI
- `scripts/` - Modular shell scripts; `config.sh` defines versions/paths, `utils.sh` has shared functions
- `conf_files/` - Service config templates (edit these, not installed files)
- `services/` - systemd unit file templates
- `brln-tools/` - Python utilities including `secure_password_manager.py`

### API Structure (api/v1/app.py)
The Flask app exposes ~115 endpoints across these categories:
- `/api/v1/system/` - Health, service status, CPU/RAM monitoring
- `/api/v1/wallet/` - HD wallet (BIP39/32/44), balances, addresses
- `/api/v1/lightning/` - Channels, peers, invoices, payments
- `/api/v1/bitcoin/` - Block info, fee estimation, RPC proxy
- `/api/v1/elements/` - Liquid asset management
- `/api/v1/lnd/wallet/` - Seed generation (aezeed), wallet init
- `/api/v1/tron/` - GasFree wallet operations

### gRPC Integration
Proto files in `api/v1/proto/` generate Python stubs. After modifying `.proto` files:
1. Run `bash scripts/gen-proto.sh`
2. Commit generated `*_pb2.py` and `*_pb2_grpc.py` files
3. Restart `brln-api` service

### Security Model
- Master password via `BRLN_MASTER_PASSWORD` env var
- Fernet encryption with PBKDF2 key derivation
- Session auth with 5-minute timeout, HTTP-only cookies
- Service isolation via dedicated users (bitcoin, lnd, brln-api)

## Development Guidelines

### When Modifying Code
- Follow existing patterns in touched files
- Edit config templates in `conf_files/`, not installed system files
- Update `api/v1/app.py` when adding API endpoints
- Use `SecurePasswordAPI` patterns for credentials, never hardcode secrets

### Proto File Changes
1. Update `.proto` in `api/v1/proto/`
2. Run `bash scripts/gen-proto.sh`
3. Update `api/v1/app.py` and clients accordingly
4. Commit generated stubs

### Frontend Changes
Files in `pages/` must be deployed via `bash scripts/maintenance.sh deploy` to copy to `/var/www/html/`.

## Key Configuration

### Versions (defined in scripts/config.sh)
- LND: 0.20.0
- Bitcoin Core: 29.2
- Network: `BITCOIN_NETWORK` env var (mainnet/testnet)

### Service Ports
| Service | Port |
|---------|------|
| API (internal) | 2121 |
| Bitcoin RPC | 8332 (mainnet) / 18332 (testnet) |
| LND gRPC | 10009 |
| Apache HTTPS | 443 |

### Virtual Environment Paths
- API: `/home/brln-api/venv` (production) or `/root/brln-os-envs/api-v1` (dev)
- Tools: `/root/brln-os-envs/tools/`

## Security Constraints

- NEVER include secrets (API keys, passwords, seed phrases) in commits
- Use environment variables and existing SecurePassword API
- Flag suspected secrets in files and advise safe handling
- For changes affecting running services, recommend tests and rollback plan
