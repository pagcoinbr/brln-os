#!/bin/bash

# BRLN-OS Dynamic Service Generator
# Creates all systemd service files dynamically instead of copying static files

# Import common functions
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Function to create bitcoind.service
create_bitcoind_service() {
    echo -e "${YELLOW}🟠 Creating bitcoind.service...${NC}"
    
    sudo tee /etc/systemd/system/bitcoind.service > /dev/null << EOF
# Bitcoin Core: systemd unit for bitcoind
# /etc/systemd/system/bitcoind.service

[Unit]
Description=Bitcoin Core Daemon
Requires=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/bitcoind -pid=/run/bitcoind/bitcoind.pid \\
                                  -conf=/data/bitcoin/bitcoin.conf \\
                                  -datadir=/data/bitcoin
# Process management
####################
Type=exec
NotifyAccess=all
PIDFile=/run/bitcoind/bitcoind.pid

Restart=on-failure
TimeoutStartSec=infinity
TimeoutStopSec=600

# Run as service users
####################
User=bitcoin
Group=bitcoin
RuntimeDirectory=bitcoind
RuntimeDirectoryMode=0755

# Hardening Measures
####################
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
PrivateDevices=true
MemoryDenyWriteExecute=true

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}✅ bitcoind.service created${NC}"
}

# Function to create lnd.service
create_lnd_service() {
    echo -e "${YELLOW}⚡ Creating lnd.service...${NC}"
    
    sudo tee /etc/systemd/system/lnd.service > /dev/null << EOF
# LND: systemd unit for lnd
# /etc/systemd/system/lnd.service

[Unit]
Description=Lightning Network Daemon
Requires=bitcoind.service
After=bitcoind.service

[Service]
ExecStart=/usr/local/bin/lnd
ExecStop=/usr/local/bin/lncli stop

# Process management
####################
Restart=on-failure
RestartSec=60
Type=notify
TimeoutStartSec=1200
TimeoutStopSec=3600

# Run as service users  
####################
User=lnd
Group=lnd

# Hardening Measures
####################
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
PrivateDevices=true

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}✅ lnd.service created${NC}"
}

# Function to create elementsd.service
create_elementsd_service() {
    echo -e "${YELLOW}🔷 Creating elementsd.service...${NC}"
    
    sudo tee /etc/systemd/system/elementsd.service > /dev/null << EOF
[Unit]
Description=Elements daemon on mainnet
# Requires=bitcoind.service
# After=bitcoind.service

[Service]
ExecStart=/usr/local/bin/elementsd -datadir=/data/elements/
User=elements
Group=elements
Restart=on-failure
TimeoutStartSec=infinity
TimeoutStopSec=600

PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
PrivateDevices=true
MemoryDenyWriteExecute=true

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}✅ elementsd.service created${NC}"
}

# Function to create peerswapd.service
create_peerswapd_service() {
    echo -e "${YELLOW}🔄 Creating peerswapd.service...${NC}"
    
    sudo tee /etc/systemd/system/peerswapd.service > /dev/null << EOF
[Unit]
Description=Peer Swap Daemon

[Service]
ExecStart=/home/peerswap/go/bin/peerswapd
User=peerswap
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}✅ peerswapd.service created${NC}"
}

# Function to create psweb.service
create_psweb_service() {
    echo -e "${YELLOW}🌐 Creating psweb.service...${NC}"
    
    sudo tee /etc/systemd/system/psweb.service > /dev/null << EOF
[Unit]
Description=PeerSwap Web UI

[Service]
ExecStart=/home/peerswap/go/bin/psweb
User=peerswap
Type=simple
KillMode=process
TimeoutSec=180
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}✅ psweb.service created${NC}"
}

# Function to setup brln-api environment and files
setup_brln_api_files() {
    echo -e "${YELLOW}📁 Setting up brln-api files and permissions...${NC}"
    
    local brln_os_source="${BRLN_OS_DIR:-/root/brln-os}"
    local brln_api_home="/home/brln-api"
    
    # Copy brln-tools directory for password manager access
    if [[ -d "$brln_os_source/brln-tools" ]]; then
        sudo cp -r "$brln_os_source/brln-tools" "$brln_api_home/"
        sudo chown -R brln-api:brln-api "$brln_api_home/brln-tools"
        echo -e "${GREEN}✅ brln-tools copied to $brln_api_home/brln-tools${NC}"
    fi
    
    # Set password database permissions for brln-api user
    local password_db="/data/brln-secure-passwords.db"
    if [[ -f "$password_db" ]]; then
        sudo chown root:brln-api "$password_db"
        sudo chmod 640 "$password_db"
        echo -e "${GREEN}✅ Password database permissions set${NC}"
    fi
    
    # Copy API files
    if [[ -d "$brln_os_source/api/v1" ]]; then
        sudo mkdir -p "$brln_api_home/api/v1"
        sudo cp "$brln_os_source/api/v1/app.py" "$brln_api_home/api/v1/"
        sudo cp "$brln_os_source/api/v1/"*.py "$brln_api_home/api/v1/" 2>/dev/null || true
        sudo chown -R brln-api:brln-api "$brln_api_home/api"
        echo -e "${GREEN}✅ API files copied${NC}"
    fi
    
    # Copy scripts (expect scripts for LND automation)
    if [[ -d "$brln_os_source/scripts" ]]; then
        sudo mkdir -p "$brln_api_home/scripts"
        sudo cp "$brln_os_source/scripts/"*.exp "$brln_api_home/scripts/" 2>/dev/null || true
        sudo chown -R brln-api:brln-api "$brln_api_home/scripts"
        sudo chmod +x "$brln_api_home/scripts/"*.exp 2>/dev/null || true
        echo -e "${GREEN}✅ Expect scripts copied${NC}"
    fi
}

# Function to create brln-api.service
create_brln_api_service() {
    echo -e "${YELLOW}🔌 Creating brln-api.service...${NC}"
    
    # Setup files first
    setup_brln_api_files
    
    # API files are always in brln-api user's home directory
    local api_dir="/home/brln-api/api/v1"
    local scripts_dir="/home/brln-api/scripts"
    
    sudo tee /etc/systemd/system/brln-api.service > /dev/null << EOF
[Unit]
Description=BRLN-OS API gRPC - Comando Central
After=network.target lnd.service

[Service]
Type=simple
User=brln-api
Group=brln-api
WorkingDirectory=${api_dir}
ExecStart=/home/brln-api/venv/bin/python3 ${api_dir}/app.py
Restart=always
RestartSec=10
Environment=PYTHONPATH=${api_dir}
Environment=BITCOIN_NETWORK=${BITCOIN_NETWORK:-mainnet}

# Security - NoNewPrivileges=false required for sudo to run expect scripts as lnd user
NoNewPrivileges=false
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    # Create sudoers file for brln-api to run LND expect scripts and manage password files
    echo -e "${YELLOW}🔐 Configuring sudoers for brln-api LND scripts...${NC}"
    cat << 'SUDOERS_EOF' | sudo tee /etc/sudoers.d/brln-api-lnd > /dev/null
# Allow brln-api to run LND expect scripts as lnd user with environment preservation
brln-api ALL=(lnd) NOPASSWD:SETENV: /home/brln-api/scripts/auto-lnd-create-masterkey.exp, /home/brln-api/scripts/auto-lnd-unlock.exp, /home/brln-api/scripts/auto-lnd-create.exp, /home/brln-api/scripts/auto-lnd-create-new.exp
# Allow brln-api to run bash for writing LND password files
brln-api ALL=(root) NOPASSWD: /usr/bin/bash -c *
SUDOERS_EOF
    sudo chmod 440 /etc/sudoers.d/brln-api-lnd
    echo -e "${GREEN}✅ Sudoers configured for brln-api${NC}"

    echo -e "${GREEN}✅ brln-api.service created${NC}"
}

# Function to create gotty-fullauto.service
create_gotty_service() {
    echo -e "${YELLOW}🌐 Creating gotty-fullauto.service...${NC}"
    
    # Determine the correct paths based on current setup
    local brln_os_dir
    if [[ -n "${BRLN_OS_DIR:-}" ]]; then
        brln_os_dir="$BRLN_OS_DIR"
    elif [[ -d "/home/admin/brln-os" ]]; then
        brln_os_dir="/home/admin/brln-os"
    else
        brln_os_dir="/root/brln-os"
    fi
    
    sudo tee /etc/systemd/system/gotty-fullauto.service > /dev/null << EOF
[Unit]
Description=Terminal Web para BRLN FullAuto
After=network.target

[Service]
User=root
WorkingDirectory=${brln_os_dir}/scripts
Environment=TERM=xterm
ExecStart=/usr/local/bin/gotty -p 3131 -w bash ${brln_os_dir}/scripts/menu.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}✅ gotty-fullauto.service created${NC}"
}

# Function to create bos-telegram.service
create_bos_telegram_service() {
    echo -e "${YELLOW}📱 Creating bos-telegram.service...${NC}"
    
    # Get telegram ID from stored credentials or use default
    local telegram_id=$(cat /home/$atual_user/.bos/*/credentials.json 2>/dev/null | jq -r '.telegram_id' | head -n1)
    if [[ -z "$telegram_id" || "$telegram_id" == "null" ]]; then
        telegram_id="your_telegram_chat_id"
    fi
    
    sudo tee /etc/systemd/system/bos-telegram.service > /dev/null << EOF
# Systemd unit for Bos-Telegram Bot
# /etc/systemd/system/bos-telegram.service

[Unit]
Description=bos-telegram
Wants=lnd.service
After=lnd.service

[Service]
ExecStart=${HOME}/.npm-global/bin/bos telegram --use-small-units --connect ${telegram_id}
User=${atual_user}
Restart=always
TimeoutSec=120
RestartSec=30
StandardOutput=null
StandardError=journal
Environment=BOS_DEFAULT_LND_PATH=/data/lnd

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}✅ bos-telegram.service created${NC}"
}

# Function to create thunderhub.service
create_thunderhub_service() {
    echo -e "${YELLOW}⚡ Creating thunderhub.service...${NC}"
    
    sudo tee /etc/systemd/system/thunderhub.service > /dev/null << EOF
# BRLN Bolt: systemd unit for Thunderhub
# /etc/systemd/system/thunderhub.service

[Unit]
Description=ThunderHub
Requires=lnd.service
After=lnd.service

[Service]
WorkingDirectory=${HOME}/thunderhub
ExecStart=/usr/bin/npm run start

User=${atual_user}
Group=${atual_user}

# Process management
####################
TimeoutSec=300

# Hardening Measures
####################
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
PrivateDevices=true

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}✅ thunderhub.service created${NC}"
}

# Function to create lnbits.service
create_lnbits_service() {
    echo -e "${YELLOW}⚡ Creating lnbits.service...${NC}"
    
    sudo tee /etc/systemd/system/lnbits.service > /dev/null << EOF
# BRLN-OS: systemd unit for LNbits
# /etc/systemd/system/lnbits.service

[Unit]
Description=LNbits
Wants=lnd.service
After=lnd.service

[Service]
WorkingDirectory=${HOME}/lnbits
ExecStart=${HOME}/lnbits/.venv/bin/python -m uvicorn lnbits.__main__:app --host 0.0.0.0 --port 5000
User=${atual_user}
Restart=always
TimeoutSec=120
RestartSec=30
StandardOutput=journal
StandardError=journal

Environment=LNBITS_DATA_FOLDER=${HOME}/lnbits/.env

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}✅ lnbits.service created${NC}"
}

# Function to create lndg.service
create_lndg_service() {
    echo -e "${YELLOW}📊 Creating lndg.service...${NC}"
    
    sudo tee /etc/systemd/system/lndg.service > /dev/null << EOF
[Unit]
Description=LNDG Service
After=lnd.service
Requires=lnd.service

[Service]
WorkingDirectory=${HOME}/lndg
ExecStart=${HOME}/lndg/.venv/bin/python3 ${HOME}/lndg/manage.py runserver 0.0.0.0:8889
User=${atual_user}
Group=${atual_user}
Restart=on-failure
Type=simple
StandardError=syslog
NotifyAccess=none

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}✅ lndg.service created${NC}"
}

# Function to create lndg-controller.service
create_lndg_controller_service() {
    echo -e "${YELLOW}🎮 Creating lndg-controller.service...${NC}"
    
    sudo tee /etc/systemd/system/lndg-controller.service > /dev/null << EOF
[Unit]
Description=Controlador de backend para Lndg
After=lnd.service
Requires=lnd.service

[Service]
Environment=PYTHONUNBUFFERED=1
User=${atual_user}
Group=${atual_user}
ExecStart=/home/${atual_user}/lndg/.venv/bin/python3 /home/${atual_user}/lndg/controller.py
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=lndg-controller
Restart=always
RestartSec=60s

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}✅ lndg-controller.service created${NC}"
}

# Function to create messager-monitor.service
create_messager_monitor_service() {
    echo -e "${YELLOW}💬 Creating messager-monitor.service...${NC}"
    
    # Determine the correct paths based on current setup
    local brln_os_dir
    if [[ -n "${BRLN_OS_DIR:-}" ]]; then
        brln_os_dir="$BRLN_OS_DIR"
    elif [[ -d "/home/admin/brln-os" ]]; then
        brln_os_dir="/home/admin/brln-os"
    else
        brln_os_dir="/root/brln-os"
    fi
    
    sudo tee /etc/systemd/system/messager-monitor.service > /dev/null << EOF
[Unit]
Description=Lightning Messager Monitor
After=lnd.service
Requires=lnd.service

[Service]
WorkingDirectory=${brln_os_dir}/api/v1
ExecStart=/home/brln-api/venv/bin/python3 ${brln_os_dir}/api/v1/messager_monitor_grpc.py
User=brln-api
Group=brln-api
Restart=always
RestartSec=10
Environment=PYTHONPATH=${brln_os_dir}/api/v1

# Security
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}✅ messager-monitor.service created${NC}"
}

# Function to create all services
create_all_services() {
    echo -e "${BLUE}🔧 Creating all BRLN-OS services...${NC}"
    echo ""
    
    create_bitcoind_service
    create_lnd_service
    create_elementsd_service
    create_peerswapd_service
    create_psweb_service
    create_brln_api_service
    create_gotty_service
    create_bos_telegram_service
    create_thunderhub_service
    create_lnbits_service
    create_lndg_service
    create_lndg_controller_service
    create_messager_monitor_service
    
    echo ""
    echo -e "${GREEN}✅ All services created successfully!${NC}"
    echo -e "${YELLOW}📋 Don't forget to reload systemd: sudo systemctl daemon-reload${NC}"
}

# Function to create specific service
create_service() {
    local service_name="$1"
    
    case "$service_name" in
        bitcoind|bitcoin)
            create_bitcoind_service
            ;;
        lnd|lightning)
            create_lnd_service
            ;;
        elementsd|elements)
            create_elementsd_service
            ;;
        peerswapd|peerswap)
            create_peerswapd_service
            ;;
        psweb|peerswap-web)
            create_psweb_service
            ;;
        brln-api|api)
            create_brln_api_service
            ;;
        gotty|gotty-fullauto)
            create_gotty_service
            ;;
        bos-telegram|bos)
            create_bos_telegram_service
            ;;
        thunderhub|thub)
            create_thunderhub_service
            ;;
        lnbits)
            create_lnbits_service
            ;;
        lndg)
            create_lndg_service
            ;;
        lndg-controller)
            create_lndg_controller_service
            ;;
        messager-monitor|messager)
            create_messager_monitor_service
            ;;
        *)
            echo -e "${RED}❌ Unknown service: $service_name${NC}"
            echo -e "${YELLOW}Available services:${NC}"
            echo "  bitcoind, lnd, elementsd, peerswapd, psweb, brln-api,"
            echo "  gotty, bos-telegram, thunderhub, lnbits, lndg, lndg-controller, messager-monitor"
            return 1
            ;;
    esac
}

# Function to show help
show_help() {
    cat << EOF
BRLN-OS Dynamic Service Generator

Usage:
  $0 [command] [service_name]

Commands:
  all                     Create all services
  create <service_name>   Create specific service
  list                    List available services
  help                    Show this help

Available Services:
  bitcoind               Bitcoin Core daemon
  lnd                    Lightning Network daemon
  elementsd              Elements/Liquid daemon  
  peerswapd              PeerSwap daemon
  psweb                  PeerSwap Web UI
  brln-api               BRLN-OS API service
  gotty                  Terminal web interface
  bos-telegram           Balance of Satoshis Telegram bot
  thunderhub             ThunderHub Lightning wallet
  lnbits                 LNbits Lightning wallet
  lndg                   Lightning Network Dashboard
  lndg-controller        LNDG backend controller
  messager-monitor       Lightning message monitor

Examples:
  $0 all                 # Create all services
  $0 create bitcoind     # Create only bitcoind service
  $0 create lnd          # Create only LND service

EOF
}

# Function to list available services
list_services() {
    echo -e "${BLUE}📋 Available BRLN-OS Services:${NC}"
    echo ""
    echo -e "${GREEN}Core Services:${NC}"
    echo "  • bitcoind - Bitcoin Core daemon"
    echo "  • lnd - Lightning Network daemon"
    echo "  • elementsd - Elements/Liquid daemon"
    echo ""
    echo -e "${GREEN}Application Services:${NC}"
    echo "  • brln-api - BRLN-OS API service"
    echo "  • messager-monitor - Lightning message monitor"
    echo "  • peerswapd - PeerSwap daemon"
    echo "  • psweb - PeerSwap Web UI"
    echo ""
    echo -e "${GREEN}Web Services:${NC}"
    echo "  • gotty - Terminal web interface"
    echo "  • thunderhub - ThunderHub Lightning wallet"
    echo "  • lnbits - LNbits Lightning wallet"
    echo "  • lndg - Lightning Network Dashboard"
    echo "  • lndg-controller - LNDG backend controller"
    echo ""
    echo -e "${GREEN}Bot Services:${NC}"
    echo "  • bos-telegram - Balance of Satoshis Telegram bot"
}

# Main execution
main() {
    case "${1:-help}" in
        all)
            create_all_services
            ;;
        create)
            if [[ -z "$2" ]]; then
                echo -e "${RED}❌ Error: Service name required${NC}"
                echo "Usage: $0 create <service_name>"
                exit 1
            fi
            create_service "$2"
            ;;
        list)
            list_services
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}❌ Unknown command: $1${NC}"
            show_help
            exit 1
            ;;
    esac
}

# Export functions for use by other scripts
export -f create_bitcoind_service
export -f create_lnd_service
export -f create_elementsd_service
export -f create_peerswapd_service
export -f create_psweb_service
export -f create_brln_api_service
export -f create_gotty_service
export -f create_bos_telegram_service
export -f create_thunderhub_service
export -f create_lnbits_service
export -f create_lndg_service
export -f create_lndg_controller_service
export -f create_messager_monitor_service
export -f create_all_services
export -f create_service

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi