#!/bin/bash

# Source required scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh" 2>/dev/null || true
source "$SCRIPT_DIR/utils.sh" 2>/dev/null || true
source "$SCRIPT_DIR/bitcoin.sh" 2>/dev/null || true
source "$SCRIPT_DIR/peerswap.sh" 2>/dev/null || true

# Function to check if Bitcoin blockchain is fully downloaded
# Usage: check_blockchain_sync "mainnet" or check_blockchain_sync "testnet"
check_blockchain_sync() {
    local network="${1:-mainnet}"  # Default to mainnet if not specified
    local datadir="/data/bitcoin"
    local conf_arg="/data/bitcoin/bitcoin.conf"
    
    # Set the appropriate data directory based on network
    if [ "$network" = "testnet" ]; then
        conf_arg="-testnet"
        echo "Checking testnet blockchain sync status..."
    else
        echo "Checking mainnet blockchain sync status..."
    fi
    
    # Check if bitcoin-cli is available
    if ! command -v bitcoin-cli &> /dev/null; then
        echo "Error: bitcoin-cli not found. Please ensure Bitcoin Core is installed."
        return 1
    fi
    
    # Get blockchain info
    local blockchain_info
    blockchain_info=$(bitcoin-cli $conf_arg getblockchaininfo 2>&1)
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to connect to Bitcoin daemon"
        echo "$blockchain_info"
        return 1
    fi
    
    # Parse the JSON response
    local blocks=$(echo "$blockchain_info" | grep -oP '"blocks":\s*\K\d+')
    local headers=$(echo "$blockchain_info" | grep -oP '"headers":\s*\K\d+')
    local verification_progress=$(echo "$blockchain_info" | grep -oP '"verificationprogress":\s*\K[0-9.]+')
    local initial_block_download=$(echo "$blockchain_info" | grep -oP '"initialblockdownload":\s*\K\w+')
    
    # Calculate sync percentage
    local sync_percentage=0
    if [ -n "$headers" ] && [ "$headers" -gt 0 ]; then
        sync_percentage=$(awk "BEGIN {printf \"%.2f\", ($blocks / $headers) * 100}")
    fi
    
    # Display status information
    echo "----------------------------------------"
    echo "Network: $network"
    echo "Current blocks: $blocks"
    echo "Total headers: $headers"
    echo "Sync progress: ${sync_percentage}%"
    echo "Verification progress: $(awk "BEGIN {printf \"%.2f\", $verification_progress * 100}")%"
    echo "Initial Block Download: $initial_block_download"
    echo "----------------------------------------"
    
    # Check if blockchain is fully synced
    if [ "$blocks" = "$headers" ] && [ "$initial_block_download" = "false" ]; then
        echo "✓ Blockchain is fully synchronized!"
        return 0
    else
        local remaining_blocks=$((headers - blocks))
        echo "⚠ Blockchain is still syncing..."
        echo "Remaining blocks: $remaining_blocks"
        return 2
    fi
}

check_lnd_sync () {
    local network_choice="$1"

    graphsync=$(lncli getinfo --network="$network_choice" | grep -oP '"synced_to_graph":\s*\K(true|false)')
    if [ "$graphsync" = "true" ]; then
        echo "LND graph is fully synchronized!"
        return 0
    else
        echo "LND graph is still syncing..."
        return 1
    fi
}

background_install () {
    local network_choice="$1"
    
    # If network not provided, try to detect from bitcoin.conf or lnd.conf
    if [ -z "$network_choice" ]; then
        if grep -q "testnet=1" /data/bitcoin/bitcoin.conf 2>/dev/null; then
            network_choice="testnet"
        else
            network_choice="mainnet"
        fi
    fi
    
    echo "Starting background installation for network: $network_choice"

    check_blockchain_sync "$network_choice"
    if [ $? -eq 0 ]; then
        echo "Blockchain sync completed successfully, downloading and installing LND..."
        download_lnd
        sleep 10
        check_lnd_sync "$network_choice"
        if [ $? -eq 0 ]; then
            echo "LND graph sync completed successfully, proceeding with further installations..."
            install_lndg
            install_peerswap
            install_psweb
            echo "✓ All installations completed successfully!"
            
            # Disable and remove the background service
            echo "Cleaning up background installation service..."
            systemctl stop brln-background-install.service 2>/dev/null || true
            systemctl disable brln-background-install.service 2>/dev/null || true
            rm -f /etc/systemd/system/brln-background-install.service
            systemctl daemon-reload
            echo "✓ Background service removed successfully!"
            
            exit 0
        else
            echo "LND graph is not yet synced. Will check again in 1 hour."
            sleep 3600  # Wait for 1 hour before rechecking
            background_install "$network_choice"
        fi
        else
        sleep 3600  # Wait for 1 hour before rechecking
        background_install "$network_choice"
    fi
}

# Get network from argument or auto-detect
NETWORK_CHOICE="${1:-}"
if [ -z "$NETWORK_CHOICE" ]; then
    if grep -q "testnet=1" /data/bitcoin/bitcoin.conf 2>/dev/null; then
        NETWORK_CHOICE="testnet"
    else
        NETWORK_CHOICE="mainnet"
    fi
fi

echo "Starting background installation monitor for $NETWORK_CHOICE network..."
background_install "$NETWORK_CHOICE"

# ============================================================================
# RESUMO DO SCRIPT INSTALL_IN_BACKGROUND.SH
# ============================================================================
#
# DESCRIÇÃO:
# - Script para monitorar sincronização do blockchain em background e executar
#   instalações (ex.: download/install LND) quando estiver pronto.
#
# FUNCIONALIDADES:
# - check_blockchain_sync(), check_lnd_sync(), background_install(): Loop de
#   verificação e acionamento automático quando pré-condições forem atendidas
#
# ============================================================================
