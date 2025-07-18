#!/bin/bash

# Script to run brunel.sh as root with proper paths
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 BRLN-OS Menu Setup${NC}"
echo

# Check if running as root
if [[ "$EUID" -eq 0 ]]; then
    echo -e "${RED}❌ Do not run this script as root directly.${NC}"
    echo -e "${YELLOW}This script will use sudo when needed.${NC}"
    exit 1
fi

# Get current directory
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_INSTALL_DIR="/root/brln-os"

# Copy files to root directory if not already there
if [[ "$CURRENT_DIR" != "$ROOT_INSTALL_DIR" ]]; then
    echo -e "${YELLOW}📋 Copying repository to root directory...${NC}"
    
    # Create root directory
    sudo mkdir -p "$ROOT_INSTALL_DIR"
    
    # Copy all files
    sudo cp -r "$CURRENT_DIR"/* "$ROOT_INSTALL_DIR/"
    
    # Set proper ownership
    sudo chown -R root:root "$ROOT_INSTALL_DIR"
    
    # Make scripts executable
    sudo chmod +x "$ROOT_INSTALL_DIR"/*.sh
    sudo chmod +x "$ROOT_INSTALL_DIR"/scripts/*.sh
    
    echo -e "${GREEN}✅ Repository copied successfully!${NC}"
else
    echo -e "${GREEN}✅ Already in correct location.${NC}"
fi

echo
echo -e "${YELLOW}🔧 Running BRLN menu as root...${NC}"
echo

# Run brunel.sh as root from the correct location
sudo bash "$ROOT_INSTALL_DIR/brunel.sh"
