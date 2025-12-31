# BRLN-OS: User & Application Matrix

## 📊 Complete System Overview

This document provides a comprehensive overview of all system users, applications, and their relationships in BRLN-OS.

---

## System Users Created

| User | Purpose | Created By | Groups |
|------|---------|------------|--------|
| `bitcoin` | Bitcoin Core daemon | bitcoin.sh | bitcoin, debian-tor |
| `lnd` | Lightning Network Daemon | bitcoin.sh | lnd, bitcoin, debian-tor |
| `elements` | Elements/Liquid daemon | elements.sh | elements |
| `peerswap` | PeerSwap & PeerSwap Web | peerswap.sh | peerswap |
| `brln-api` | BRLN-OS API service | brunel.sh | brln-api |
| `$atual_user` (admin) | Lightning apps & management | - | bitcoin, lnd, brln-api |
| `root` | System services | - | - |

---

## Applications by User

### 🟠 User: `bitcoin`

**Bitcoin Core (bitcoind)** - v29.1
- **Binary:** `/usr/local/bin/bitcoind`, `/usr/local/bin/bitcoin-cli`
- **Data Directory:** `/data/bitcoin/`
- **Configuration:** `/data/bitcoin/bitcoin.conf`
- **Service:** `bitcoind.service`
- **Groups:** `bitcoin`, `debian-tor`
- **Ports:** 8332 (RPC), 8333 (P2P)
- **Credentials:** Stored in password manager

---

### ⚡ User: `lnd`

**Lightning Network Daemon (lnd)** - v0.20.0
- **Binary:** `/usr/local/bin/lnd`, `/usr/local/bin/lncli`
- **Data Directory:** `/data/lnd/`
- **Configuration:** `/data/lnd/lnd.conf`
- **Service:** `lnd.service`
- **Groups:** `lnd`, `bitcoin`, `debian-tor`
- **Ports:** 9735 (P2P), 10009 (gRPC), 8080 (REST)
- **Wallet Password:** Stored in password manager
- **Access:** Admin user added to `lnd` group
- **ZMQ Integration:** Connected to Bitcoin Core

---

### 🔥 User: `elements`

**Elements Core (elementsd)** - v23.3.1
- **Binary:** `/usr/local/bin/elementsd`, `/usr/local/bin/elements-cli`
- **Data Directory:** `/data/elements/`
- **Configuration:** `/data/elements/elements.conf`
- **Service:** `elementsd.service`
- **Chain:** Liquid mainnet (liquidv1)
- **Ports:** 7041 (RPC), 7042 (P2P)
- **RPC Credentials:** Stored in password manager
- **Features:**
  - Transaction indexing (txindex=1)
  - Peg-in validation (validatepegin=1)
  - Asset directories for DePix and USDT

---

### 🔄 User: `peerswap`

**PeerSwap Daemon (peerswapd)** - v4.0rc1
- **Binary:** `/home/peerswap/go/bin/peerswapd`
- **CLI:** `/home/peerswap/go/bin/pscli`
- **Configuration:** `/home/peerswap/.peerswap/peerswap.conf`
- **Service:** `peerswapd.service`
- **Source:** Compiled from GitHub (ElementsProject/peerswap)
- **Features:**
  - Liquid swaps enabled
  - Bitcoin swaps disabled
  - Elements wallet: peerswap

**PeerSwap Web UI (psweb)**
- **Binary:** `/home/peerswap/go/bin/psweb`
- **Service:** `psweb.service`
- **Port:** 1984
- **Source:** Compiled from GitHub (Impa10r/peerswap-web)
- **Features:**
  - Liquid Peg-in interface
  - Channel rebalancing with L-BTC
  - Auto-fee management

---

### � User: `brln-api`

**BRLN-OS API Service** - Flask + gRPC
- **Binary:** `/home/brln-api/venv/bin/python3`
- **Application:** `/home/admin/brln-os/api/v1/app.py`
- **Data Directory:** `/data/brln-wallet/`
- **Virtual Environment:** `/home/brln-api/venv/`
- **Service:** `brln-api.service`
- **Group:** `brln-api`
- **Port:** 2121 (HTTP API)
- **Database:** SQLite (`wallets.db`, `lightning_chat.db`)
- **Features:**
  - Wallet management and generation
  - System status monitoring
  - Lightning Network gRPC interface
  - Multi-blockchain support (Bitcoin, Elements, TRON)
  - Encrypted wallet storage
  - Chat database for Lightning messaging

---

### �👤 User: `$atual_user` (admin/main user)

**Balance of Satoshis (bos)**
- **Binary:** `~/.npm-global/bin/bos`
- **Configuration:** `~/.bos/<nodename>/credentials.json`
- **Service:** `bos-telegram.service`
- **Installation:** npm global package
- **Features:**
  - Telegram bot integration
  - Auto-capture Telegram ID
  - Node management CLI
- **Credentials:** Telegram API key stored in password manager

**ThunderHub**
- **Location:** `/home/$atual_user/thunderhub/`
- **Service:** `thunderhub.service`
- **Port:** 3000
- **User:** `$atual_user`
- **Installation:** Git clone + npm
- **Version:** From config.sh (VERSION_THUB)
- **Features:**
  - Web-based Lightning dashboard
  - GPG signature verification
  - Master/account password generation
- **Credentials:** Stored in password manager

**LNDg (Lightning Node Dashboard)**
- **Location:** `/home/$atual_user/lndg/`
- **Services:** `lndg.service`, `lndg-controller.service`
- **Port:** 8889
- **User:** `$atual_user`
- **Installation:** Git clone + Python virtualenv
- **Environment:** `.venv` (Python 3)
- **Features:**
  - Django-based dashboard
  - Real-time node monitoring
  - Auto-generated admin password
- **Credentials:** Admin password stored in password manager

---

### 🔒 User: `root`

**GoTTY (Web Terminal)**
- **Service:** `gotty-fullauto.service`
- **Configuration:** `/root/.gotty`
- **Port:** 8998
- **Features:**
  - Web-based terminal access
  - TLS/SSL support
  - Authentication required

---

## System Services (No Dedicated User)

### 🔐 Security & Privacy

**UFW (Uncomplicated Firewall)**
- Managed via: `ufw` commands
- Configuration: `/etc/ufw/`
- IPv4 and IPv6 support
- Default: deny incoming, allow outgoing

**Tor**
- User: `debian-tor` (system user)
- Service: `tor.service`
- ControlPort: 9051
- SOCKS5: 9050
- Used by: Bitcoin, LND

**I2P**
- User: `i2psvc` (system user)
- Service: `i2p.service`
- HTTP Proxy: 4444
- HTTPS Proxy: 4445
- SAM: 7656

**Fail2ban**
- User: `root`
- Service: `fail2ban.service`
- Protection: SSH, web services

---

## Group Memberships & Permissions

```
bitcoin group:
├── bitcoin (owner)
├── lnd (member) - needs access to RPC
└── $atual_user (member) - admin access

lnd group:
├── lnd (owner)
└── $atual_user (member) - admin access, Lightning apps

debian-tor group:
├── debian-tor (owner)
├── bitcoin (member) - Tor integration
└── lnd (member) - Tor integration

elements group:
└── elements (owner)

peerswap group:
└── peerswap (owner)
```

---

## Data Directory Structure

```
/data/
├── bitcoin/                    # owned by bitcoin:bitcoin (750)
│   ├── bitcoin.conf            # 640
│   ├── blocks/
│   ├── chainstate/
│   └── .rpcpass                # 600
│
├── lnd/                        # owned by lnd:lnd (750)
│   ├── lnd.conf                # 640
│   ├── tls.cert
│   ├── tls.key
│   ├── wallet.db
│   └── data/
│       └── chain/bitcoin/mainnet/
│           └── admin.macaroon
│
├── elements/                   # owned by elements:elements (750)
│   ├── elements.conf           # 600
│   ├── liquidv1/
│   └── wallets/
│       └── peerswap/
│
└── brln-passwords.db           # owned by root:root (600)
    # SQLite database with bcrypt hashed passwords

/home/$atual_user/
├── thunderhub/                 # Lightning web UI
│   ├── .env.local
│   ├── package.json
│   └── node_modules/
│
├── lndg/                       # Lightning dashboard
│   ├── .venv/                  # Python virtualenv
│   ├── data/
│   │   └── lndg-admin.txt      # admin password
│   └── manage.py
│
├── .bos/                       # BOS configuration
│   └── <nodename>/
│       └── credentials.json    # 600
│
├── .npm-global/                # npm global packages
│   └── bin/
│       └── bos
│
├── .lnd -> /data/lnd           # symlink
└── .bitcoin -> /data/bitcoin   # symlink

/home/peerswap/
├── peerswap/                   # source code
│   ├── Makefile
│   └── build/
│
├── peerswap-web/               # web UI source
│   └── Makefile
│
├── go/
│   └── bin/
│       ├── peerswapd
│       ├── pscli
│       └── psweb
│
└── .peerswap/
    └── peerswap.conf           # 600
```

---

## Service Dependencies

```
Network Dependencies:
bitcoind.service
    ↓
lnd.service
    ↓
├── thunderhub.service
├── lndg.service
│   └── lndg-controller.service
├── bos-telegram.service
└── peerswapd.service
        ↓
    psweb.service

Elements Chain:
elementsd.service
    ↓
peerswapd.service (uses Elements wallet)
```

---

## Port Assignments

| Service | Port | Protocol | Access |
|---------|------|----------|--------|
| Bitcoin RPC | 8332 | TCP | localhost |
| Bitcoin P2P | 8333 | TCP | public |
| LND gRPC | 10009 | TCP | localhost |
| LND REST | 8080 | TCP | localhost |
| LND P2P | 9735 | TCP | public |
| Elements RPC | 7041 | TCP | localhost |
| Elements P2P | 7042 | TCP | public |
| ThunderHub | 3000 | TCP | LAN |
| LNDg | 8889 | TCP | LAN |
| PeerSwap Web | 1984 | TCP | LAN |
| GoTTY | 8998 | TCP | LAN |
| Tor SOCKS | 9050 | TCP | localhost |
| Tor Control | 9051 | TCP | localhost |
| I2P HTTP | 4444 | TCP | localhost |
| I2P HTTPS | 4445 | TCP | localhost |

---

## Password Manager Integration

All credentials are stored securely in the password manager:

**Location:** `/data/brln-passwords.db`  
**Hashing:** bcrypt (12 rounds)  
**Access:** CLI via password_manager.py  
**Menu:** password_manager_menu.sh

### Stored Credentials:

1. **bitcoin_rpc** - Bitcoin Core RPC password
2. **lnd_wallet** - LND wallet unlock password
3. **elements_rpc_user** - Elements RPC username
4. **elements_rpc_password** - Elements RPC password
5. **lndg_admin** - LNDg dashboard admin password
6. **thunderhub_master** - ThunderHub master password
7. **thunderhub_account** - ThunderHub account password
8. **bos_telegram_id** - BOS Telegram user ID
9. **bos_telegram_bot** - BOS Telegram bot API key

Each entry includes:
- Service name
- Username/identifier
- Password (bcrypt hashed)
- Description
- Port
- URL/access information
- Timestamp

---

## Installation Scripts

| Script | Purpose | Users Created |
|--------|---------|---------------|
| bitcoin.sh | Bitcoin Core + LND | bitcoin, lnd |
| elements.sh | Elements/Liquid | elements |
| lightning.sh | Lightning apps | - |
| peerswap.sh | PeerSwap + Web UI | peerswap |
| system.sh | Security (UFW, Tor, I2P) | - |
| gotty.sh | Web terminal | - |

---

## Security Summary

✅ **Principle of Least Privilege**
- Each daemon runs as dedicated user
- Group-based access control
- Minimal permission grants

✅ **Credential Management**
- Centralized password storage
- bcrypt hashing (12 rounds)
- No plain text passwords in configs

✅ **Network Security**
- UFW firewall configured
- Tor integration for privacy
- I2P support for anonymity
- Fail2ban for brute force protection

✅ **Service Isolation**
- Systemd service confinement
- User/group separation
- Process isolation via systemd directives

✅ **File Permissions**
- Sensitive configs: 600 (owner only)
- Data directories: 750 (owner + group)
- Binaries: 755 (world executable)

---

## Verification Checklist

### Pre-Installation
- [ ] System updated: `sudo apt update && sudo apt upgrade`
- [ ] Sufficient disk space (~500GB recommended)
- [ ] Stable internet connection

### Post-Installation
- [ ] All users created: `bitcoin`, `lnd`, `elements`, `peerswap`
- [ ] All services enabled: `systemctl list-units --type=service`
- [ ] Password manager populated: Check via menu
- [ ] Firewall configured: `sudo ufw status`
- [ ] Tor running: `systemctl status tor`
- [ ] Bitcoin syncing: `bitcoin-cli getblockchaininfo`
- [ ] LND syncing: `lncli getinfo`
- [ ] Elements syncing: `elements-cli getblockchaininfo`

### Network Access
- [ ] ThunderHub accessible: `http://<IP>:3000`
- [ ] LNDg accessible: `http://<IP>:8889`
- [ ] PeerSwap Web accessible: `http://<IP>:1984`
- [ ] GoTTY accessible: `http://<IP>:8998`

---

## Troubleshooting

### Check Service Status
```bash
sudo systemctl status bitcoind
sudo systemctl status lnd
sudo systemctl status elementsd
sudo systemctl status peerswapd
sudo systemctl status psweb
sudo systemctl status thunderhub
sudo systemctl status lndg
```

### Check Logs
```bash
journalctl -u bitcoind -f
journalctl -u lnd -f
journalctl -u elementsd -f
journalctl -u peerswapd -f
```

### View Credentials
```bash
cd /root/brln-os/scripts
./password_manager_menu.sh
# Select option 1: List all credentials
```

### Verify Group Memberships
```bash
groups bitcoin  # should show: bitcoin debian-tor
groups lnd      # should show: lnd bitcoin debian-tor
id $atual_user  # should show bitcoin and lnd groups
```

---

## Maintenance

### Regular Tasks
- **Weekly:** Check disk space: `df -h /data`
- **Weekly:** Review logs for errors
- **Monthly:** Update system packages
- **Monthly:** Backup password database and wallet seeds
- **Quarterly:** Review and update Lightning node

### Backup Locations
- **Critical:** `/data/brln-passwords.db`
- **Critical:** `/data/lnd/data/chain/bitcoin/mainnet/wallet.db`
- **Critical:** LND seed phrase (24 words)
- **Important:** `/data/bitcoin/bitcoin.conf`
- **Important:** `/data/lnd/lnd.conf`
- **Important:** `/data/elements/elements.conf`

---

## Additional Notes

### Why Separate Users?

1. **Security Isolation:** If one service is compromised, others remain protected
2. **Permission Control:** Each service only has access to its own files
3. **Audit Trail:** Clear ownership and accountability for each process
4. **Resource Management:** Easier to track resource usage per service
5. **Best Practice:** Industry standard for multi-service systems

### Why Lightning Apps Run as Admin User?

The Lightning applications (LNDg, ThunderHub, BOS) run as the admin user because:
- They need interactive access to LND macaroons
- They require web interface access from admin context
- They benefit from simplified credential management
- The security risk is acceptable given their purpose
- Creating separate users would add complexity without significant security benefit

---

**Document Version:** 1.0  
**Last Updated:** December 29, 2025  
**Maintained By:** BRLN-OS Development Team  
**License:** Same as BRLN-OS project
