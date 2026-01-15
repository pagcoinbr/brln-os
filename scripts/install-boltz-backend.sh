#!/bin/bash

# Boltz Backend Installation Script for BRLN-OS
# Installs Boltz backend for atomic swaps across Bitcoin, Lightning, and Liquid
# Version: 1.0

set -e  # Exit on any error

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"

# Boltz backend configuration
BOLTZ_VERSION="master"  # Use latest master or specific tag like "v3.5.0"
BOLTZ_INSTALL_DIR="/opt/boltz-backend"
BOLTZ_USER="boltz-backend"
BOLTZ_HOME="/home/$BOLTZ_USER"
BOLTZ_CONFIG_DIR="$BOLTZ_HOME/.boltz"
BOLTZ_API_PORT=9001

# Main installation function
install_boltz_backend() {
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}   Installing Boltz Backend for Atomic Swaps${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Check prerequisites
    check_prerequisites

    # Install Node.js 22 LTS
    install_nodejs_22

    # Create Boltz backend user
    create_boltz_user

    # Clone and install Boltz backend
    clone_boltz_repository

    # Install dependencies
    install_boltz_dependencies

    # Generate configuration
    generate_boltz_config

    # Create systemd service
    create_boltz_service

    # Start service
    start_boltz_service

    # Verify installation
    verify_boltz_installation

    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ Boltz Backend installation complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}📋 Service management:${NC}"
    echo -e "   ${YELLOW}sudo systemctl status boltz-backend${NC}  - Check status"
    echo -e "   ${YELLOW}sudo systemctl restart boltz-backend${NC} - Restart service"
    echo -e "   ${YELLOW}sudo journalctl -u boltz-backend -f${NC}  - View logs"
    echo ""
    echo -e "${BLUE}🔗 API endpoint:${NC} ${YELLOW}http://localhost:$BOLTZ_API_PORT${NC}"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}🔍 Checking prerequisites...${NC}"

    # Check if LND is installed
    if ! command -v lnd &> /dev/null; then
        echo -e "${YELLOW}⚠️  LND not found. Boltz backend requires LND for Lightning swaps.${NC}"
        echo -e "${YELLOW}   Install LND first, then run this script again.${NC}"
    fi

    # Check if Bitcoin Core is installed
    if ! command -v bitcoind &> /dev/null; then
        echo -e "${YELLOW}⚠️  Bitcoin Core not found. Boltz backend requires bitcoind.${NC}"
        echo -e "${YELLOW}   Install Bitcoin Core first, then run this script again.${NC}"
    fi

    # Check if Elements is installed (optional but recommended)
    if ! command -v elementsd &> /dev/null; then
        echo -e "${YELLOW}⚠️  Elements not found. Liquid swaps will not be available.${NC}"
        echo -e "${YELLOW}   To enable Liquid swaps, install Elements first.${NC}"
    fi

    # Check if PostgreSQL is installed (required)
    if ! command -v psql &> /dev/null; then
        echo -e "${RED}❌ PostgreSQL not found. Installing PostgreSQL...${NC}"
        sudo apt update
        sudo apt install -y postgresql postgresql-contrib
        sudo systemctl enable postgresql
        sudo systemctl start postgresql
        echo -e "${GREEN}✅ PostgreSQL installed${NC}"
    else
        echo -e "${GREEN}✅ PostgreSQL found${NC}"
    fi

    echo ""
}

# Install Node.js 22 LTS
install_nodejs_22() {
    echo -e "${BLUE}📦 Installing Node.js 22 LTS...${NC}"

    # Check current Node.js version
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ "$NODE_VERSION" -ge 22 ]]; then
            echo -e "${GREEN}✅ Node.js $NODE_VERSION is already installed${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️  Node.js $NODE_VERSION found, but v22+ required${NC}"
            echo -e "${BLUE}   Upgrading to Node.js 22 LTS...${NC}"
        fi
    fi

    # Add NodeSource repository for Node.js 22
    echo -e "${BLUE}   Adding NodeSource repository...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -

    # Install Node.js
    echo -e "${BLUE}   Installing Node.js 22...${NC}"
    sudo apt-get install -y nodejs

    # Verify installation
    if command -v node &> /dev/null && command -v npm &> /dev/null; then
        NODE_VER=$(node --version)
        NPM_VER=$(npm --version)
        echo -e "${GREEN}✅ Node.js ${NODE_VER} installed${NC}"
        echo -e "${GREEN}✅ npm ${NPM_VER} installed${NC}"
    else
        echo -e "${RED}❌ Failed to install Node.js${NC}"
        exit 1
    fi

    echo ""
}

# Create Boltz backend user
create_boltz_user() {
    echo -e "${BLUE}👤 Creating Boltz backend user...${NC}"

    # Create system user if it doesn't exist
    if ! id -u "$BOLTZ_USER" &>/dev/null; then
        sudo useradd -r -m -s /bin/bash "$BOLTZ_USER"
        echo -e "${GREEN}✅ User '$BOLTZ_USER' created${NC}"
    else
        echo -e "${GREEN}✅ User '$BOLTZ_USER' already exists${NC}"
    fi

    # Create home directory if it doesn't exist
    if [[ ! -d "$BOLTZ_HOME" ]]; then
        sudo mkdir -p "$BOLTZ_HOME"
        sudo chown -R $BOLTZ_USER:$BOLTZ_USER "$BOLTZ_HOME"
    fi

    # Add boltz-backend user to necessary groups for LND/Bitcoin access
    sudo usermod -a -G bitcoin,lnd "$BOLTZ_USER" 2>/dev/null || true

    echo ""
}

# Clone Boltz backend repository
clone_boltz_repository() {
    echo -e "${BLUE}📥 Cloning Boltz backend repository...${NC}"

    # Remove existing directory if it exists
    if [[ -d "$BOLTZ_INSTALL_DIR" ]]; then
        echo -e "${YELLOW}⚠️  Existing installation found at $BOLTZ_INSTALL_DIR${NC}"
        echo -e "${BLUE}   Backing up existing installation...${NC}"
        sudo mv "$BOLTZ_INSTALL_DIR" "${BOLTZ_INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    fi

    # Clone repository
    sudo mkdir -p "$BOLTZ_INSTALL_DIR"
    sudo git clone https://github.com/BoltzExchange/boltz-backend.git "$BOLTZ_INSTALL_DIR"

    cd "$BOLTZ_INSTALL_DIR"

    # Checkout specific version if not using master
    if [[ "$BOLTZ_VERSION" != "master" ]]; then
        sudo git checkout "$BOLTZ_VERSION"
        echo -e "${GREEN}✅ Checked out version: $BOLTZ_VERSION${NC}"
    else
        echo -e "${GREEN}✅ Using master branch${NC}"
    fi

    # Set ownership
    sudo chown -R $BOLTZ_USER:$BOLTZ_USER "$BOLTZ_INSTALL_DIR"

    echo ""
}

# Install Boltz dependencies and compile
install_boltz_dependencies() {
    echo -e "${BLUE}📦 Installing Boltz backend dependencies...${NC}"
    echo -e "${YELLOW}   This may take several minutes...${NC}"

    cd "$BOLTZ_INSTALL_DIR"

    # Install dependencies as boltz-backend user
    sudo -u $BOLTZ_USER npm install --production

    echo -e "${BLUE}🔨 Compiling TypeScript and Rust components...${NC}"

    # Compile TypeScript
    sudo -u $BOLTZ_USER npm run compile:typescript

    # Compile Rust (if cargo is available)
    if command -v cargo &> /dev/null; then
        sudo -u $BOLTZ_USER npm run compile:rust || true
    else
        echo -e "${YELLOW}⚠️  Rust not installed, skipping Rust compilation${NC}"
        echo -e "${YELLOW}   Some advanced features may not be available${NC}"
    fi

    # Verify compilation
    if [[ -f "$BOLTZ_INSTALL_DIR/bin/boltzd" ]]; then
        echo -e "${GREEN}✅ Boltz backend compiled successfully${NC}"
    else
        echo -e "${RED}❌ Compilation failed - boltzd binary not found${NC}"
        exit 1
    fi

    echo ""
}

# Generate Boltz configuration
generate_boltz_config() {
    echo -e "${BLUE}⚙️  Generating Boltz configuration...${NC}"

    # Create config directory
    sudo mkdir -p "$BOLTZ_CONFIG_DIR"

    # Get database password (reuse existing or generate new)
    if [[ -f "/home/brln-api/.env" ]]; then
        DB_PASSWORD=$(grep POSTGRES_PASSWORD /home/brln-api/.env | cut -d'=' -f2 | tr -d '"' || echo "brln_secure_$(openssl rand -hex 16)")
    else
        DB_PASSWORD="brln_secure_$(openssl rand -hex 16)"
    fi

    # Get Bitcoin RPC password
    if [[ -f "$HOME/.bitcoin/bitcoin.conf" ]]; then
        BTC_RPC_USER=$(grep "^rpcuser=" "$HOME/.bitcoin/bitcoin.conf" | cut -d'=' -f2 || echo "brln")
        BTC_RPC_PASS=$(grep "^rpcpassword=" "$HOME/.bitcoin/bitcoin.conf" | cut -d'=' -f2 || echo "")
    else
        BTC_RPC_USER="brln"
        BTC_RPC_PASS=$(openssl rand -hex 16)
    fi

    # Get Liquid RPC password (if Elements is installed)
    if [[ -f "$HOME/.elements/elements.conf" ]]; then
        LIQUID_RPC_USER=$(grep "^rpcuser=" "$HOME/.elements/elements.conf" | cut -d'=' -f2 || echo "brln")
        LIQUID_RPC_PASS=$(grep "^rpcpassword=" "$HOME/.elements/elements.conf" | cut -d'=' -f2 || echo "")
    else
        LIQUID_RPC_USER="brln"
        LIQUID_RPC_PASS=$(openssl rand -hex 16)
    fi

    # Determine network (mainnet or testnet)
    NETWORK=${BITCOIN_NETWORK:-mainnet}

    # Set ports based on network
    if [[ "$NETWORK" == "testnet" ]]; then
        BTC_RPC_PORT=18332
        LND_GRPC_PORT=10009
        LIQUID_RPC_PORT=18884
    else
        BTC_RPC_PORT=8332
        LND_GRPC_PORT=10009
        LIQUID_RPC_PORT=7041
    fi

    # Generate boltz.conf
    cat > "$BOLTZ_CONFIG_DIR/boltz.conf" <<EOF
# Boltz Backend Configuration for BRLN-OS
# Generated: $(date)

# Database configuration
[postgres]
host = "127.0.0.1"
port = 5432
database = "brln_swaps"
username = "brln-api"
password = "$DB_PASSWORD"

# Bitcoin configuration
[currencies.BTC]
symbol = "BTC"
network = "$NETWORK"
host = "127.0.0.1"
port = $BTC_RPC_PORT
cookie = "$HOME/.bitcoin/$NETWORK/.cookie"

# LND configuration
[lnd.BTC]
host = "127.0.0.1"
port = $LND_GRPC_PORT
certpath = "/home/lnd/.lnd/tls.cert"
macaroonpath = "/home/lnd/.lnd/data/chain/bitcoin/$NETWORK/admin.macaroon"

# Liquid configuration (if Elements is installed)
[currencies.L-BTC]
symbol = "L-BTC"
network = "liquid$NETWORK"
host = "127.0.0.1"
port = $LIQUID_RPC_PORT
cookie = "$HOME/.elements/liquid$NETWORK/.cookie"

# Trading pairs
[pairs.BTC/BTC]
rate = 1
fee = 0.001
timeoutDelta = 288

[pairs."L-BTC/BTC"]
rate = 1
fee = 0.001
timeoutDelta = 144

[pairs."L-BTC/L-BTC"]
rate = 1
fee = 0.0005
timeoutDelta = 144

# API configuration
[api]
host = "127.0.0.1"
port = $BOLTZ_API_PORT

# Notification configuration (optional)
[notification]
# Discord webhook URL (optional)
# discordUrl = ""

# Backup configuration (optional)
[backup]
# interval = 86400
# email = ""

EOF

    # Set permissions
    sudo chown -R $BOLTZ_USER:$BOLTZ_USER "$BOLTZ_CONFIG_DIR"
    sudo chmod 600 "$BOLTZ_CONFIG_DIR/boltz.conf"

    echo -e "${GREEN}✅ Configuration generated at $BOLTZ_CONFIG_DIR/boltz.conf${NC}"
    echo ""
}

# Create systemd service
create_boltz_service() {
    echo -e "${BLUE}🔧 Creating systemd service...${NC}"

    # Create systemd service file
    sudo tee /etc/systemd/system/boltz-backend.service > /dev/null <<EOF
[Unit]
Description=Boltz Backend - Atomic Swap Service
Documentation=https://github.com/BoltzExchange/boltz-backend
After=network.target postgresql.service bitcoind.service lnd.service elementsd.service
Wants=postgresql.service bitcoind.service lnd.service
PartOf=lnd.service

[Service]
Type=simple
User=$BOLTZ_USER
Group=$BOLTZ_USER
WorkingDirectory=$BOLTZ_INSTALL_DIR
Environment="NODE_ENV=production"
Environment="HOME=$BOLTZ_HOME"
ExecStart=/usr/bin/node bin/boltzd
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=boltz-backend

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=false

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd daemon
    sudo systemctl daemon-reload

    # Enable service
    sudo systemctl enable boltz-backend

    echo -e "${GREEN}✅ Systemd service created and enabled${NC}"
    echo ""
}

# Start Boltz service
start_boltz_service() {
    echo -e "${BLUE}🚀 Starting Boltz backend service...${NC}"

    # Start service
    sudo systemctl start boltz-backend

    # Wait a few seconds for service to start
    sleep 5

    # Check if service is running
    if systemctl is-active --quiet boltz-backend; then
        echo -e "${GREEN}✅ Boltz backend service started successfully${NC}"
    else
        echo -e "${RED}❌ Failed to start Boltz backend service${NC}"
        echo -e "${YELLOW}   Checking logs for errors...${NC}"
        sudo journalctl -u boltz-backend -n 50 --no-pager
        exit 1
    fi

    echo ""
}

# Verify Boltz installation
verify_boltz_installation() {
    echo -e "${BLUE}🔍 Verifying Boltz backend installation...${NC}"

    # Wait for API to be ready
    sleep 3

    # Check API health
    if curl -s http://localhost:$BOLTZ_API_PORT/version >/dev/null; then
        VERSION=$(curl -s http://localhost:$BOLTZ_API_PORT/version | jq -r '.version' 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✅ Boltz backend API responding (version: $VERSION)${NC}"
    else
        echo -e "${YELLOW}⚠️  Boltz backend API not responding yet${NC}"
        echo -e "${YELLOW}   This is normal on first start. Check logs with:${NC}"
        echo -e "${YELLOW}   sudo journalctl -u boltz-backend -f${NC}"
    fi

    # Check supported pairs
    if curl -s http://localhost:$BOLTZ_API_PORT/v2/swap/pairs >/dev/null; then
        PAIRS=$(curl -s http://localhost:$BOLTZ_API_PORT/v2/swap/pairs | jq -r 'keys | length' 2>/dev/null || echo "0")
        echo -e "${GREEN}✅ Configured with $PAIRS trading pairs${NC}"
    fi

    echo ""
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_boltz_backend
fi
