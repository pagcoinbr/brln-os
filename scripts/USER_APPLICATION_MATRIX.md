# BRLN-OS: User & Application Matrix

## Overview

This document lists system users, services, and how they relate in BRLN-OS.
Note: when `BITCOIN_BACKEND=remote`, the `bitcoin` user and `bitcoind.service`
are not created and `/data/bitcoin` is not used.

---

## System Users Created

| User | Purpose | Created By | Groups |
|------|---------|------------|--------|
| `bitcoin` | Bitcoin Core daemon (local backend only) | bitcoin.sh | bitcoin, debian-tor |
| `lnd` | Lightning Network Daemon | bitcoin.sh | lnd, bitcoin, debian-tor |
| `brln-api` | BRLN-OS API service | brunel.sh | brln-api |
| `$atual_user` (admin) | Lightning apps & management | - | bitcoin, lnd, brln-api |
| `root` | System services | - | - |

---

## Applications by User

### User: `bitcoin` (local backend only)

**Bitcoin Core (bitcoind)** - v29.1
- **Binary:** `/usr/local/bin/bitcoind`, `/usr/local/bin/bitcoin-cli`
- **Data Directory:** `/data/bitcoin/`
- **Configuration:** `/data/bitcoin/bitcoin.conf`
- **Service:** `bitcoind.service`
- **Ports:** 8332 (RPC), 8333 (P2P)
- **Credentials:** Stored in password manager

---

### User: `lnd`

**Lightning Network Daemon (lnd)** - v0.20.0
- **Binary:** `/usr/local/bin/lnd`, `/usr/local/bin/lncli`
- **Data Directory:** `/data/lnd/`
- **Configuration:** `/data/lnd/lnd.conf`
- **Service:** `lnd.service`
- **Groups:** `lnd`, `bitcoin`, `debian-tor`
- **Ports:** 9735 (P2P), 10009 (gRPC), 8080 (REST)
- **Wallet Password:** Stored in password manager
- **Access:** Admin user added to `lnd` group
- **ZMQ Integration:** Connected to local bitcoind or remote ZMQ endpoints

---

### User: `brln-api`

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
  - Encrypted wallet storage
  - Chat database for Lightning messaging

---

### User: `$atual_user` (admin/main user)

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

### User: `root`

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
  bitcoin (owner)
  lnd (member) - needs access to RPC
  $atual_user (member) - admin access

lnd group:
  lnd (owner)
  $atual_user (member) - admin access, Lightning apps

debian-tor group:
  debian-tor (owner)
  bitcoin (member) - Tor integration
  lnd (member) - Tor integration
```

---

## Data Directory Structure

```
/data/
|-- bitcoin/                    # owned by bitcoin:bitcoin (750) [local backend only]
|   |-- bitcoin.conf            # 640
|   |-- blocks/
|   |-- chainstate/
|   `-- .rpcpass                # 600
|
|-- lnd/                        # owned by lnd:lnd (750)
|   |-- lnd.conf                # 640
|   |-- tls.cert
|   |-- tls.key
|   |-- wallet.db
|   `-- data/
|       `-- chain/bitcoin/mainnet/
|           `-- admin.macaroon
|
`-- brln-passwords.db           # owned by root:root (600)
    # SQLite database with encrypted secrets (Fernet)

/home/$atual_user/
|-- .env.local
|-- lndg/
|   |-- .venv/
|   |-- data/
|   |   `-- lndg-admin.txt
|   `-- manage.py
|-- .bos/
|   `-- <nodename>/
|       `-- credentials.json
|-- .npm-global/
|   `-- bin/
|       `-- bos
|-- .lnd -> /data/lnd           # symlink
`-- .bitcoin -> /data/bitcoin   # symlink (local backend only)
```

---

## Service Dependencies

```
bitcoind.service (local)
    |
    v
lnd.service
    |
    v
lndg.service
lndg-controller.service
bos-telegram.service
```

---

## Port Assignments

| Service | Port | Protocol | Access |
|---------|------|----------|--------|
| Bitcoin RPC | 8332 | TCP | localhost (local backend) |
| Bitcoin P2P | 8333 | TCP | public |
| LND gRPC | 10009 | TCP | localhost |
| LND REST | 8080 | TCP | localhost |
| LND P2P | 9735 | TCP | public |
| LNDg | 8889 | TCP | LAN |
| GoTTY | 8998 | TCP | LAN |
| Tor SOCKS | 9050 | TCP | localhost |
| Tor Control | 9051 | TCP | localhost |
| I2P HTTP | 4444 | TCP | localhost |
| I2P HTTPS | 4445 | TCP | localhost |

---

## Password Manager Integration

All credentials are stored securely in the password manager:

**Location:** `/data/brln-passwords.db`  
**Encryption:** Fernet with PBKDF2-derived key (no password hash stored)  
**Access:** CLI via secure_password_manager.py  
**Menu:** password_manager_menu.sh

### Stored Credentials:

1. **bitcoin_rpc** - Bitcoin Core RPC password
2. **lnd_wallet** - LND wallet unlock password
3. **lndg_admin** - LNDg dashboard admin password
4. **bos_telegram_id** - BOS Telegram user ID
5. **bos_telegram_bot** - BOS Telegram bot API key

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
| lightning.sh | Lightning apps | - |
| system.sh | Security (UFW, Tor, I2P) | - |
| gotty.sh | Web terminal | - |

---

## Verification Checklist

### Pre-Installation
- [ ] System updated: `sudo apt update && sudo apt upgrade`
- [ ] Sufficient disk space (full node ~1TB, pruned node less)
- [ ] Stable internet connection

### Post-Installation
- [ ] All services enabled: `systemctl list-units --type=service`
- [ ] Password manager populated: Check via menu
- [ ] Firewall configured: `sudo ufw status`
- [ ] Tor running: `systemctl status tor`
- [ ] Bitcoin syncing (local backend): `bitcoin-cli getblockchaininfo`
- [ ] Bitcoin RPC reachable (remote backend): `curl` or `bitcoin-cli -rpc*` from LND host
- [ ] LND syncing: `lncli getinfo`

### Network Access
- [ ] LNDg accessible: `http://<IP>:8889`
- [ ] GoTTY accessible: `http://<IP>:8998`

---

## Troubleshooting

### Check Service Status
```bash
sudo systemctl status bitcoind
sudo systemctl status lnd
sudo systemctl status lndg
```

### Check Logs
```bash
journalctl -u bitcoind -f
journalctl -u lnd -f
```

### View Credentials
```bash
cd /root/brln-os/scripts
./password_manager_menu.sh
# Select option 1: List all credentials
```

### Verify Group Memberships
```bash
groups bitcoin  # should show: bitcoin debian-tor (local backend)
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
- **Important:** `/data/bitcoin/bitcoin.conf` (local backend)
- **Important:** `/data/lnd/lnd.conf`

---

## Additional Notes

### Why Separate Users?

1. **Security Isolation:** If one service is compromised, others remain protected
2. **Permission Control:** Each service only has access to its own files
3. **Audit Trail:** Clear ownership and accountability for each process
4. **Resource Management:** Easier to track resource usage per service
5. **Best Practice:** Industry standard for multi-service systems

### Why Lightning Apps Run as Admin User?

- They need interactive access to LND macaroons
- They require web interface access from admin context
- They benefit from simplified credential management
- The security risk is acceptable given their purpose
- Creating separate users would add complexity without significant security benefit

---

**Document Version:** 1.1  
**Last Updated:** January 4, 2026  
**Maintained By:** BRLN-OS Development Team  
**License:** Same as BRLN-OS project
