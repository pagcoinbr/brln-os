#!/bin/bash

# BRLN-OS Quick Start Script
# This script sets up permissions and starts all services

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}[BRLN-OS]${NC} $1"
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                   BRLN-OS Quick Start                    ║"
    echo "║          Setting up permissions and starting services    ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Check if we're in the right directory
    if [[ ! -f "$SCRIPT_DIR/docker-compose.yml" ]]; then
        echo "Error: docker-compose.yml not found in current directory"
        echo "Please run this script from the container/nodes directory"
        exit 1
    fi
    
    # Run permission setup
    print_header "Step 1: Setting up permissions..."
    if [[ -f "$SCRIPT_DIR/setup-permissions.sh" ]]; then
        sudo "$SCRIPT_DIR/setup-permissions.sh"
    else
        echo "Error: setup-permissions.sh not found"
        exit 1
    fi
    
    echo
    print_header "Step 2: Starting services..."
    podman-compose up -d
    
    echo
    print_header "Step 3: Checking service status..."
    sleep 5
    podman-compose ps
    
    echo
    print_status "✅ BRLN-OS services started successfully!"
    echo
    echo "Next steps:"
    echo "- Monitor logs: podman-compose logs -f"
    echo "- Check Bitcoin: podman exec -it bitcoind bitcoin-cli getblockchaininfo"
    echo "- Check Elements: podman exec -it elementsd elements-cli getblockchaininfo"
    echo "- Check LND (after sync): podman exec -it lnd lncli getinfo"
    echo
}

main "$@"
