<div align="center">

# BRLN-OS v2.0 – Bitcoin Multi-Node Operating System

[![Bitcoin](https://img.shields.io/badge/Bitcoin-₿-FF9900?style=for-the-badge&logo=bitcoin&logoColor=white)](https://bitcoin.org)
[![Lightning Network](https://img.shields.io/badge/Lightning-⚡-792EE5?style=for-the-badge&logo=lightning&logoColor=white)](https://lightning.network)
[![Liquid Network](https://img.shields.io/badge/Liquid%20Network-LBTC-00B800?style=for-the-badge&logo=liquid&logoColor=white)](https://liquid.net)
[![TRON](https://img.shields.io/badge/TRON-TRX-E50914?style=for-the-badge&logo=tron&logoColor=white)](https://tron.network)
[![Linux](https://img.shields.io/badge/Linux-Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Open Source](https://img.shields.io/badge/Open%20Source-MIT-green?style=for-the-badge&logo=opensourceinitiative&logoColor=white)](LICENSE)
[![Free Banking](https://img.shields.io/badge/Free%20Banking-Self%20Sovereign-blue?style=for-the-badge&logo=bank&logoColor=white)](#)
[![Privacy First](https://img.shields.io/badge/Privacy-First-purple?style=for-the-badge&logo=tor&logoColor=white)](#)

**BRLN-OS** is a complete Linux distribution that transforms any Ubuntu server into a full Bitcoin + Lightning Network node, focusing on individual sovereignty, financial privacy, and usability for the Brazilian public and beyond.

<img width="1541" height="915" alt="BRLN-OS Main Interface" src="https://github.com/user-attachments/assets/530a8642-38b6-4f77-85c9-1f53ced2aa7a" />

It automates the installation, configuration, and integration of **Bitcoin Core**, **LND**, and a complete suite of Lightning Network tools and monitoring systems, exposing everything through a proprietary web interface and local services, without depending on third parties.

---

<img width="1487" height="912" alt="Bitcoin Node Architecture" src="https://github.com/user-attachments/assets/cabf3db7-8b91-4289-8078-49f78444d7b4" />

---

</div>

## 📑 Table of Contents

- [Why This Project Exists](#-why-this-project-exists)
- [Installation Guide](#-installation-guide)
- [Architecture Overview](#-architecture-overview)
- [Main Components](#-main-components)
- [System Requirements](#-system-requirements)
- [Quick Start](#-quick-start)
- [Project Structure](#-project-structure)
- [Privacy & Security](#-privacy--security)
- [Updating the System](#-updating-the-system)
- [Credits & Related Projects](#-credits--related-projects)
- [Community & Support](#-community--support)
- [License](#-license)

---

<div align="center">

## 🎯 Why This Project Exists?

BRLN-OS is built on fundamental principles:

**Financial Privacy as a Right**  
Transactions and balances must be controlled by you, running on your own infrastructure, without third-party custody

**Digital Sovereignty**  
The node runs on your hardware, with free software and self-hosted services

**Surveillance Resistance**  
Use of Tor, I2P support (i2pd), and optional VPN (Tailscale) to reduce metadata exposure

**Individual Empowerment**  
Portuguese interface, interactive menus, and automation to reduce the technical barrier of operating a complete Bitcoin/Lightning node

The main motivation is to **protect the privacy and financial freedom** of individuals, especially in contexts where surveillance and financial control are increasing.

</div>

---

## 🚀 Installation Guide

### Step 1: Download Ubuntu 24.04 LTS

1. Visit the official Canonical website: [https://ubuntu.com/download/server](https://ubuntu.com/download/server)
2. Download **Ubuntu 24.04 LTS Server** (ISO file)
3. Save the ISO file to your computer

### Step 2: Create Bootable USB

1. Download **Balena Etcher**: [https://www.balena.io/etcher/](https://www.balena.io/etcher/)
2. Install Balena Etcher on your computer
3. Insert your USB drive (minimum 8GB) - ⚠️ **All data will be erased!**
4. Open Balena Etcher:
   - Click "Flash from file" and select the Ubuntu ISO
   - Click "Select target" and choose your USB drive
   - Click "Flash!" and wait for completion (5-15 minutes)
5. Eject the USB safely

### Step 3: Install Ubuntu Server

1. Insert the USB into your target machine and boot from it
   - Press F12, F2, ESC, or DEL to access boot menu
   - Select the USB drive
2. Follow the Ubuntu installation wizard:
   - Configure language, keyboard, and network
   - **Create a user account** (remember credentials!)
   - **Select "Install OpenSSH server"** (important for remote access)
   - Complete installation and reboot

### Step 4: Connect via SSH

1. Find your Ubuntu machine's IP address:
   ```bash
   ip addr show
   ```
   Look for an IP like 192.168.x.x or 10.0.x.x

2. Connect from another computer:
   ```bash
   ssh your_username@YOUR_IP_ADDRESS
   ```

### Step 5: Install BRLN-OS

Once connected via SSH, run this single command:

```bash
git clone https://github.com/pagcoinbr/brln-os.git && cd brln-os && bash brunel.sh
```

This command will:
- Clone the BRLN-OS repository
- Navigate into the directory
- Run the installation script with interactive menu

### Step 6: Initial Setup

When you first access the web interface at `http://YOUR_IP_ADDRESS`:

**Scenario 1: Fresh Installation**
- Interactive terminal setup opens automatically
- Follow the `menu.sh` prompts to configure your system
- Create your first wallet

**Scenario 2: LND Directory Exists but No Wallet**
- Wallet creation interface opens
- Create or import a wallet
- Configure your Lightning node

**Scenario 3: Everything Configured**
- Direct access to the main dashboard
- Your system is ready to use!

For detailed installation instructions, see [INSTALLATION_TUTORIAL.md](INSTALLATION_TUTORIAL.md).

---

<div align="center">

## 🏗️ Architecture Overview

BRLN-OS provides:

**Bitcoin Core** as on-chain backend, configured for use with Tor and I2P  
**LND (Lightning Network Daemon)** as main Lightning node  
**Lightning Applications**: ThunderHub, LNbits, LNDg, Balance of Satoshis, and Simple LNWallet  
**Web Interface in Portuguese** served via Apache, with main page at `main.html` and components in `pages/`  
**BRLN API** (Flask + gRPC) to expose system status, wallet, and Lightning operations via HTTP  
**Web Terminal (Gotty)** for browser-based shell access (if enabled)  
**Systemd-managed services** with unit files in `services/`

<img width="1487" height="912" alt="System Architecture" src="https://github.com/user-attachments/assets/b1c1eb9b-49b4-40bb-864f-aab7b89d97d2" />

Everything is designed to run locally, behind Tor and/or VPN, reducing the need to expose ports directly to the Internet.

</div>

---

## 🔧 Main Components

### 3.1 Core Bitcoin & Lightning

**Bitcoin Core**
- Installed from official binaries via `scripts/bitcoin.sh`
- Default data directory: `/home/bitcoin/.bitcoin`
- Base configuration in `conf_files/bitcoin.conf` (includes Tor proxy and I2P support via i2pd)

**LND (Lightning Network Daemon)**
- Installed via `scripts/bitcoin.sh` (function `download_lnd`)
- Default data directory: `/home/lnd/.lnd`
- Base configuration in `conf_files/lnd.conf`
- gRPC integration with BRLN API (see `api/v1/`)

### 3.2 Lightning Applications

<div align="center">

<img width="1463" height="908" alt="Lightning Apps" src="https://github.com/user-attachments/assets/e231791c-67d4-4f33-a85f-9fab1848a5c7" />

</div>

Installed and managed by `scripts/lightning.sh` and interactive menu in `scripts/menu.sh`:

- **ThunderHub** – Modern web interface for LND
- **LNbits** – Multi-user Lightning wallet server
- **LNDg** – Advanced dashboard for channel management and rebalancing
- **Balance of Satoshis (BOS)** – CLI tool for automation and channel management
- **Simple LNWallet** – Minimalist web wallet integrated into the interface

### 3.3 Web Interface & Proxy

**Apache Web Server** configured by `scripts/apache.sh` and `scripts/system.sh`:
- Copies `main.html`, `pages/` and static assets to `/var/www/html/`
- Serves the interface at `http://YOUR_NODE_IP/`

**Apache Reverse Proxy** documented in `conf_files/README-Apache-Proxy.md`:
- Maps internal services to unique paths (`/thunderhub/`, `/lnbits/`, `/lndg/`, `/simple-lnwallet/`, `/api/`)
- Resolves SameSite cookie and iframe issues, keeping everything under the same domain

### 3.4 BRLN API

Implemented in `api/v1/app.py` (Flask + gRPC):

**System Management**
- System status (CPU, RAM, LND, Bitcoin, etc.)
- Service management (start/stop/restart)
- Health checks

**On-chain Wallet**
- Bitcoin balance and transactions
- Send BTC, generate addresses, manage UTXOs

**Lightning Network**
- Peers, channels, invoices, payments
- Keysend, fees, routing
- Channel management

Bridges with LND via gRPC using protos in `api/v1/proto/`
- Systemd service: `services/brln-api.service`

### 3.5 Privacy & Network

**Tor**
- Installed and enabled via `scripts/system.sh`
- Bitcoin Core configured to use Tor proxy (see `conf_files/bitcoin.conf`)

**I2P (i2pd)**
- Support configured in `bitcoin.conf` for I2P connections (i2psam)

**Tailscale VPN**
- Installed via `scripts/system.sh`
- Recommended for secure remote access instead of public port forwarding

### 3.6 Web Terminal (Gotty)

- Installed and managed via `scripts/gotty.sh`
- Systemd services: `gotty.service`, `gotty-fullauto.service`, and log/editor services
- Opens in iframe modal for seamless integration

---

<div align="center">

## 📋 System Requirements

<img width="1513" height="912" alt="System Requirements" src="https://github.com/user-attachments/assets/e5300d16-a11a-40e0-bf3e-3674ef21e1d0" />

</div>

### Operating System

- **Ubuntu Server 22.04 LTS or 24.04 LTS** (recommended)
- Supported architectures:
  - `x86_64` (standard PC/server)
  - `arm64`/`aarch64` (including newer Raspberry Pi)

### Minimum Hardware

- **CPU**: 64-bit processor, 2 GHz dual-core or better
- **RAM**: 4 GB minimum, **8 GB recommended**
- **Storage**: 500 GB SSD minimum for Bitcoin mainnet (less for testnet or aggressive pruning)
- **Network**: Stable internet connection with good upload bandwidth

### Network Requirements

- SSH access to server (port 22)
- HTTP/HTTPS access on local network (ports 80 and 443) for web interface
- **Recommended**: Do NOT expose ports directly to the Internet; use Tailscale or another VPN

---

## ⚡ Quick Start

For those comfortable with command line on Ubuntu Server:

1. Ensure you're logged in as a user with `sudo` privileges (e.g., `admin`)

2. Update the system:
   ```bash
   sudo apt update && sudo apt upgrade -y
   sudo apt install git -y
   ```

3. Clone the repository:
   ```bash
   git clone https://github.com/pagcoinbr/brln-os.git
   cd brln-os
   ```

4. Run the interactive installation menu:
   ```bash
   chmod +x brunel.sh
   ./brunel.sh
   ```

5. Access the web interface:
   - Open browser to `http://YOUR_NODE_IP/`

---

## 📁 Project Structure

Simplified overview of main directories:

```text
brln-os/
├── brunel.sh              # Main installation script with interactive menu
├── main.html              # Main web interface page
├── pages/                 # Interface components (home, tools, bitcoin, lightning, etc.)
│   ├── home/              # Home page with wallet status checker
│   ├── components/        # UI components
│   │   ├── bitcoin/       # Bitcoin on-chain interface
│   │   ├── lightning/     # Lightning Network interface
│   │   ├── elements/      # Elements/Liquid interface
│   │   ├── wallet/        # HD Wallet manager
│   │   ├── tron/          # TRON wallet (gas-free)
│   │   └── config/        # System configuration panel
├── scripts/               # Modular shell scripts
│   ├── config.sh          # Global configuration, paths, architecture
│   ├── utils.sh           # Utility functions (spinner, safe_cp, firewall, etc.)
│   ├── apache.sh          # Apache setup and deployment
│   ├── bitcoin.sh         # Bitcoin Core + LND installation
│   ├── lightning.sh       # Lightning apps (ThunderHub, LNbits, BOS, API)
│   ├── gotty.sh           # Web terminal
│   ├── system.sh          # System tools (Tor, Tailscale, cron, sudoers)
│   ├── menu.sh            # Main interactive menu
│   ├── elements.sh        # Elements/Liquid support
│   └── peerswap.sh        # PeerSwap integration
├── api/
│   └── v1/
│       ├── app.py         # Flask + gRPC API integrating with LND
│       ├── requirements.txt
│       ├── proto/         # LND .proto files
│       └── *_pb2*.py      # Generated gRPC files
├── conf_files/
│   ├── bitcoin.conf       # Default Bitcoin Core config (Tor + I2P)
│   ├── lnd.conf           # Default LND config
│   ├── README-Apache-Proxy.md
│   └── setup-apache-proxy.sh
├── services/              # Systemd unit files for all services
├── brln-tools/            # Utility tools (BIP39, password manager, etc.)
└── INSTALLATION_TUTORIAL.md  # Detailed installation guide
```

---

## 🔐 Privacy & Security

BRLN-OS is designed to **protect privacy**, but final configuration depends on you. Recommendations:

### Privacy Best Practices

**Run Behind Tor and I2P**
- Use provided `bitcoin.conf` as base
- Install Tor via menu "System Tools" (`scripts/system.sh`)
- Bitcoin Core automatically uses Tor proxy

**Avoid Direct Port Exposure**
- Access via LAN or Tailscale VPN
- If external access needed, use HTTPS with valid certificates and proper firewall

**Secure Backups**
- Regular backups of:
  - `/home/bitcoin/.bitcoin` (or your data directory)
  - `/home/lnd/.lnd` (includes seed, macaroon, channels.db)
  - Data directories of LNbits, LNDg, and other services

**User Segregation**
- Each service runs with its own system user (bitcoin, lnd, lnbits, etc.)
- Reduces impact of failures and improves security

**Frequent Updates**
- BRLN-OS can configure automatic `git pull` via cron
- Run `./brunel.sh` periodically to check for updates

### Security Checklist

- [ ] Tor installed and running
- [ ] Firewall (UFW) configured
- [ ] Strong passwords for all wallets
- [ ] SSH key authentication enabled
- [ ] Regular backups of wallet seeds
- [ ] System updated regularly

**Remember**: Privacy is an ongoing process. Regularly review your attack surface, open ports, and dependencies.

---

## 🔄 Updating the System

To update BRLN-OS code and managed components:

```bash
cd /path/to/brln-os
./brunel.sh update
```

This command:
- Performs `git pull` on repository
- Updates Python dependencies (API)
- Updates and redeploys web interface via Apache
- Revalidates sudoers permissions and update cron

---

## 🛠️ Systemd Services

Files in `services/` define how each component runs in the background:

| Service | Description |
|---------|-------------|
| `bitcoind.service` | Bitcoin Core daemon |
| `lnd.service` | Lightning Network Daemon |
| `lnbits.service` | LNbits multi-user wallet server |
| `thunderhub.service` | ThunderHub web dashboard |
| `lndg.service` + `lndg-controller.service` | LNDg dashboard and controller |
| `simple-lnwallet.service` | Simple LNWallet web interface |
| `bos-telegram.service` | Balance of Satoshis Telegram bot |
| `lightning-monitor.service` | Lightning monitoring service |
| `brln-api.service` | BRLN API (Flask + gRPC) |
| `gotty*.service` | Web terminal and admin tools |
| `elementsd.service` | Elements/Liquid daemon |
| `peerswapd.service` + `psweb.service` | PeerSwap and web UI |

Interact with services via `systemctl`:

```bash
sudo systemctl status bitcoind
sudo systemctl start lnd
sudo systemctl enable thunderhub
sudo systemctl restart brln-api
```

BRLN-OS adds specific sudoers entries to allow admin user to manage services without password prompts.

---

## 🎓 Credits & Related Projects

BRLN-OS integrates or is inspired by various open-source projects:

- **[Bitcoin Core](https://github.com/bitcoin/bitcoin)** – Reference implementation
- **[LND](https://github.com/lightningnetwork/lnd)** – Lightning Network Daemon by Lightning Labs
- **[ThunderHub](https://github.com/apotdevin/thunderhub)** – Modern LND web interface
- **[LNbits](https://github.com/lnbits/lnbits)** – Banking layer over Lightning
- **[LNDg](https://github.com/cryptosharks131/lndg)** – Advanced LND dashboard
- **[Balance of Satoshis](https://github.com/alexbosworth/balanceofsatoshis)** – LND CLI admin tool
- **[Simple LNWallet](https://github.com/jvxis/simple-lnwallet-go)** – Minimalist Lightning wallet
- **[Gotty](https://github.com/yudai/gotty)** – Web-based terminal
- **[Tailscale](https://github.com/tailscale/tailscale)** – VPN mesh network

Study the official documentation of each project to understand limits, risks, and best practices.

---

<div align="center">

## 💬 Community & Support

<img width="842" height="332" alt="Community" src="https://github.com/user-attachments/assets/9a7369ec-438d-40ea-bf91-41dc717d9d96" />

</div>

### Get Help

- **Telegram**: [https://t.me/pagcoinbr](https://t.me/pagcoinbr)
- **Email**: suporte.brln@gmail.com | suporte@brln-os
- **Website**: [https://services.br-ln.com](https://services.br-ln.com)
- **GitHub Issues**: [https://github.com/pagcoinbr/brln-os/issues](https://github.com/pagcoinbr/brln-os/issues)

### Contributing

Contributions are welcome! We value:

- Security and privacy improvements
- UX enhancements
- Bug fixes and documentation updates
- Translation to other languages

**How to contribute:**

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for the full text.

---

<div align="center">

## 🌟 Features at a Glance

✅ **Full Bitcoin Node** – Sync and validate the entire blockchain  
✅ **Lightning Network** – Send/receive instant, low-fee payments  
✅ **Web Interface** – User-friendly dashboard in Portuguese  
✅ **Privacy First** – Tor and I2P integration by default  
✅ **Self-Hosted** – No third-party dependencies  
✅ **Multi-Currency Support** – Bitcoin, Elements/Liquid, TRON  
✅ **HD Wallet Manager** – BIP39 seed management  
✅ **Channel Management** – ThunderHub, LNDg, BOS integration  
✅ **API Access** – RESTful API with gRPC backend  
✅ **Automatic Updates** – Configurable auto-update via cron  
✅ **Professional Monitoring** – System status and service management  
✅ **Open Source** – MIT licensed, community-driven  

---

**Built with ❤️ for Bitcoin financial freedom and sovereignty**

*BRLN-OS – Banking for the People, by the People*

</div>
