#!/bin/bash

# BRLN-OS LND Wallet Initialization Script
# Uses API-generated seed with lncli create

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔑 BRLN-OS LND Wallet Initialization${NC}"
echo -e "${BLUE}====================================${NC}"

# Function to generate seed via API
generate_seed() {
    echo -e "${YELLOW}📱 Generating seed phrase via API...${NC}"
    
    # Try API port 2121 first (local), then 5000 (proxy)
    local api_response
    if api_response=$(curl -s -X POST http://localhost:2121/api/v1/wallet/generate \
        -H "Content-Type: application/json" \
        -d '{"word_count": 24}' 2>/dev/null); then
        echo -e "${GREEN}✅ Seed generated via local API (port 2121)${NC}"
    elif api_response=$(curl -s -X POST http://localhost:5000/api/v1/wallet/generate \
        -H "Content-Type: application/json" \
        -d '{"word_count": 24}' 2>/dev/null); then
        echo -e "${GREEN}✅ Seed generated via proxy API (port 5000)${NC}"
    else
        echo -e "${RED}❌ Failed to connect to API on both ports 2121 and 5000${NC}"
        exit 1
    fi
    
    # Extract mnemonic from response
    local mnemonic=$(echo "$api_response" | jq -r '.mnemonic')
    local wallet_id=$(echo "$api_response" | jq -r '.wallet_id')
    
    if [[ "$mnemonic" == "null" || -z "$mnemonic" ]]; then
        echo -e "${RED}❌ Failed to extract mnemonic from API response${NC}"
        echo "API Response: $api_response"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Generated 24-word seed phrase${NC}"
    echo -e "${BLUE}📋 Wallet ID: $wallet_id${NC}"
    echo -e "${BLUE}🔑 Seed phrase: $mnemonic${NC}"
    echo
    
    # Store in variables for use
    export GENERATED_SEED="$mnemonic"
    export WALLET_ID="$wallet_id"
}

# Function to initialize LND wallet
init_lnd_wallet() {
    echo -e "${YELLOW}🚀 Initializing LND wallet...${NC}"
    
    # Check if LND is running and waiting for wallet
    if ! systemctl is-active --quiet lnd; then
        echo -e "${RED}❌ LND service is not running${NC}"
        echo -e "${YELLOW}💡 Starting LND service...${NC}"
        systemctl start lnd
        sleep 5
    fi
    
    # Check LND status
    local lnd_status=$(systemctl show -p StatusText lnd | cut -d= -f2)
    if [[ "$lnd_status" != "Wallet locked" ]]; then
        echo -e "${YELLOW}⚠️  LND Status: $lnd_status${NC}"
    fi
    
    echo -e "${BLUE}🔐 Please enter wallet password when prompted${NC}"
    echo -e "${BLUE}📝 You'll need to enter the seed phrase manually${NC}"
    echo -e "${BLUE}🔑 Use this seed: $GENERATED_SEED${NC}"
    echo
    echo -e "${YELLOW}Press ENTER to start lncli create...${NC}"
    read
    
    # Run lncli create
    echo -e "${GREEN}🚀 Running lncli create...${NC}"
    lncli create
    
    echo
    echo -e "${GREEN}✅ LND wallet initialization completed!${NC}"
}

# Function to test LND connection after init
test_lnd_connection() {
    echo -e "${YELLOW}🧪 Testing LND connection...${NC}"
    
    sleep 3
    
    if lncli getinfo >/dev/null 2>&1; then
        echo -e "${GREEN}✅ LND is running and responsive!${NC}"
        lncli getinfo | jq '{
            identity_pubkey: .identity_pubkey,
            alias: .alias,
            version: .version,
            block_height: .block_height,
            synced_to_chain: .synced_to_chain,
            num_peers: .num_peers,
            num_active_channels: .num_active_channels
        }'
    else
        echo -e "${YELLOW}⚠️  LND may still be starting up...${NC}"
    fi
}

# Main execution
main() {
    generate_seed
    init_lnd_wallet
    test_lnd_connection
    
    echo
    echo -e "${GREEN}🎉 LND Wallet Setup Complete!${NC}"
    echo -e "${BLUE}📋 Wallet ID: $WALLET_ID${NC}"
    echo -e "${BLUE}🔑 Seed saved in API database${NC}"
    echo -e "${YELLOW}💡 You can now use lncli commands or the API endpoints${NC}"
}

# Run main function
main "$@"