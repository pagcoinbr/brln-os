# BRLN-OS Modular Structure

## 📁 Directory Organization

```
brln-os/
├── brunel_new.sh           # Main orchestrator script
├── brunel.sh              # Legacy monolithic script (backup)
└── scripts/               # Modular subscripts directory
    ├── config.sh          # Configuration & environment variables
    ├── utils.sh           # Utility functions (spinner, safe_cp, etc.)
    ├── apache.sh          # Apache web server setup & deployment
    ├── gotty.sh           # Terminal web interface (Gotty)
    ├── bitcoin.sh         # Bitcoin Core & LND installation
    ├── lightning.sh       # Lightning apps (ThunderHub, LNbits, BOS)
    ├── system.sh          # System updates, Tor, VPN, security
    └── menu.sh            # Interactive menu system
```

## 🚀 Usage

### Command Line Options:
```bash
./brunel_new.sh              # Default: system update/upgrade
./brunel_new.sh menu         # Interactive menu system
./brunel_new.sh update       # System update
./brunel_new.sh install      # Quick installation
./brunel_new.sh help         # Show help
```

## 🧩 Modular Components

### 1. **config.sh** - Core Configuration
- Smart path detection (auto-detects `/root/brln-os` vs `/home/admin/brlnfullauto`)
- Environment variables & colors
- Architecture detection
- Network configuration

### 2. **utils.sh** - Utility Functions
- `safe_cp()` - Safe file copying with error checking
- `spinner()` - Loading animation with success/error status
- `configure_ufw()` - Firewall setup
- `close_ports_except_ssh()` - Security hardening

### 3. **apache.sh** - Web Server
- `setup_apache_web()` - Complete Apache configuration
- `deploy_to_apache()` - Deploy files to web server
- `setup_https_proxy()` - HTTPS proxy configuration
- Smart file deployment from `pages/` directory

### 4. **gotty.sh** - Terminal Web Interface
- `gotty_install()` - Install Gotty binary
- `install_gotty_services()` - Install systemd services
- `terminal_web()` - Complete terminal web setup
- Smart path detection for gotty archives

### 5. **bitcoin.sh** - Bitcoin Stack
- `install_bitcoind()` - Bitcoin Core installation
- `download_lnd()` - Lightning Network Daemon
- `configure_lnd()` - LND configuration
- `install_complete_stack()` - Full Bitcoin+Lightning stack

### 6. **lightning.sh** - Lightning Applications
- `install_thunderhub()` - Web interface for LND
- `lnbits_install()` - Lightning wallet
- `install_bos()` - Balance of Satoshis
- `setup_lightning_monitor()` - Monitoring setup
- `install_brln_api()` - gRPC API service

### 7. **system.sh** - System Management
- `update_and_upgrade()` - Main system update function
- `install_tor()` - Tor network setup
- `tailscale_vpn()` - VPN installation
- Environment setup & dependency management

### 8. **menu.sh** - Interactive Interface
- `menu()` - Main menu system
- `menu_bitcoin_stack()` - Bitcoin/Lightning options
- `menu_lightning_apps()` - Lightning application menu  
- `menu_web_interface()` - Web interface menu
- `menu_system_tools()` - System tools menu

## ✨ Key Improvements

### 🔧 **Smart Path Detection**
- Automatically detects directory structure
- Works with `/root/brln-os`, `/home/admin/brlnfullauto`, or script directory
- Fallback paths for services, local apps, etc.

### 🛡️ **Error Handling**
- `safe_cp()` function checks file existence before copying
- Color-coded error messages
- Proper exit codes and status checking

### 📦 **Modular Design**
- Each component is self-contained
- Easy to maintain and debug
- Individual functions can be tested separately
- Clear separation of concerns

### 🎨 **User Experience**
- Interactive menu system with clear options
- Command-line arguments for automation
- Visual feedback with colors and emojis
- Help system with usage examples

## 🔄 Migration from Monolithic Script

The original `brunel.sh` has been preserved as a backup. The new modular system:

1. **Maintains compatibility** - Same functionality, better organization
2. **Improves maintainability** - Each module focuses on specific tasks
3. **Enables easier testing** - Individual components can be tested
4. **Simplifies debugging** - Issues isolated to specific modules
5. **Allows selective loading** - Only load needed components

## 🚀 Next Steps

1. **Test each module individually**
2. **Add more granular error handling**
3. **Create unit tests for each function**
4. **Add logging capabilities**
5. **Implement configuration file support**
6. **Add update mechanisms for individual components**

The modular structure makes BRLN-OS much more maintainable and allows for easier development of new features!