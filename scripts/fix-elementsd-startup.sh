#!/bin/bash
# Elements Daemon Quick Fix Script
# Addresses the two startup issues identified in the error logs

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}      ELEMENTS DAEMON STARTUP ERROR FIX${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
   exit 1
fi

echo -e "${YELLOW}📋 Fixing Issue 1: Tor Permission Error${NC}"
echo ""
echo -e "${BLUE}Adding 'elements' user to 'debian-tor' group...${NC}"

if usermod -aG debian-tor elements; then
    echo -e "${GREEN}✓ Elements user added to debian-tor group${NC}"
else
    echo -e "${RED}✗ Failed to add elements user to debian-tor group${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}📋 Fixing Issue 2: Bitcoin RPC Connection${NC}"
echo ""
echo "Choose one of the following options:"
echo ""
echo "  [1] RECOMMENDED: Disable pegin validation (simple setup)"
echo "  [2] Configure Bitcoin RPC connection (full setup)"
echo "  [3] View current Bitcoin configuration"
echo ""

read -p "Select option (1-3): " option

case $option in
    1)
        echo ""
        echo -e "${BLUE}Disabling pegin validation in elements.conf...${NC}"
        
        if [[ -f /data/elements/elements.conf ]]; then
            # Backup original config
            cp /data/elements/elements.conf /data/elements/elements.conf.bak
            echo -e "${GREEN}✓ Backup created: /data/elements/elements.conf.bak${NC}"
            
            # Replace validatepegin=1 with validatepegin=0
            sed -i 's/^validatepegin=1/validatepegin=0/' /data/elements/elements.conf
            echo -e "${GREEN}✓ Updated elements.conf: validatepegin=0${NC}"
        else
            echo -e "${RED}✗ elements.conf not found at /data/elements/elements.conf${NC}"
            exit 1
        fi
        ;;
    2)
        echo ""
        echo -e "${BLUE}Configuring Bitcoin RPC connection...${NC}"
        
        # Check Bitcoin Core RPC cookie
        if [[ -f /data/bitcoin/.cookie ]]; then
            BITCOIN_CREDS=$(cat /data/bitcoin/.cookie)
            IFS=':' read -r BITCOIN_USER BITCOIN_PASS <<< "$BITCOIN_CREDS"
            
            echo -e "${GREEN}✓ Found Bitcoin Core RPC credentials${NC}"
            echo -e "  User: ${BLUE}$BITCOIN_USER${NC}"
            echo -e "  Pass: ${BLUE}[REDACTED]${NC}"
            
            # Update Elements config
            if [[ -f /data/elements/elements.conf ]]; then
                # Backup original config
                cp /data/elements/elements.conf /data/elements/elements.conf.bak
                echo -e "${GREEN}✓ Backup created: /data/elements/elements.conf.bak${NC}"
                
                # Comment out old RPC settings and add new ones
                sed -i '/^# mainchainrpchost/,/^# mainchainrpcpassword/d' /data/elements/elements.conf
                
                # Append new RPC settings before fallbackfee
                sed -i '/^fallbackfee/i\
# Bitcoin Core RPC Configuration for Pegin Validation\
mainchainrpchost=127.0.0.1\
mainchainrpcport=8332\
mainchainrpcuser='"$BITCOIN_USER"'\
mainchainrpcpassword='"$BITCOIN_PASS"'
' /data/elements/elements.conf
                
                echo -e "${GREEN}✓ Updated elements.conf with Bitcoin RPC credentials${NC}"
            else
                echo -e "${RED}✗ elements.conf not found at /data/elements/elements.conf${NC}"
                exit 1
            fi
        else
            echo -e "${YELLOW}⚠️  Bitcoin Core RPC cookie not found${NC}"
            echo -e "   Path: /data/bitcoin/.cookie"
            echo ""
            echo -e "${BLUE}Please configure Bitcoin RPC manually:${NC}"
            echo -e "   1. Edit /data/elements/elements.conf"
            echo -e "   2. Uncomment and update mainchainrpc* settings"
            echo -e "   3. Use Bitcoin Core credentials from /data/bitcoin/bitcoin.conf"
        fi
        ;;
    3)
        echo ""
        echo -e "${BLUE}Current Bitcoin Core configuration:${NC}"
        echo ""
        grep -E "^rpc|^server|^daemon" /data/bitcoin/bitcoin.conf 2>/dev/null || echo "No RPC config found"
        echo ""
        echo -e "${BLUE}Bitcoin Core RPC Cookie:${NC}"
        if [[ -f /data/bitcoin/.cookie ]]; then
            echo -e "${GREEN}✓ Found at /data/bitcoin/.cookie${NC}"
        else
            echo -e "${RED}✗ Not found${NC}"
        fi
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${YELLOW}🔄 Restarting Elements daemon...${NC}"
echo ""

if systemctl restart elementsd; then
    echo -e "${GREEN}✓ Elements daemon restarted${NC}"
else
    echo -e "${RED}✗ Failed to restart Elements daemon${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}⏳ Waiting for daemon to stabilize...${NC}"
sleep 3

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}      STATUS CHECK${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if systemctl is-active --quiet elementsd; then
    echo -e "${GREEN}✓ Elements daemon is RUNNING${NC}"
else
    echo -e "${RED}✗ Elements daemon is NOT running${NC}"
    echo ""
    echo -e "${YELLOW}View logs with:${NC}"
    echo -e "   ${BLUE}journalctl -u elementsd -n 50 -f${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
