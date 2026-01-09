#!/bin/bash

# Lock file to prevent multiple instances
LOCK_FILE="/tmp/brln_background_install.lock"
LOG_FILE="/var/log/brln-background-install.log"

# Function to log with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if another instance is running
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE")
    if ps -p "$pid" > /dev/null 2>&1; then
        log_message "Another instance is already running (PID: $pid). Exiting."
        exit 0
    else
        log_message "Removing stale lock file"
        rm -f "$LOCK_FILE"
    fi
fi

# Create lock file
echo $$ > "$LOCK_FILE"

# Ensure lock file is removed on exit
trap "rm -f '$LOCK_FILE'" EXIT

# Source required scripts
SCRIPTS_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRLN_OS_DIR="$(dirname "$SCRIPTS_PATH")"

# Source scripts with error checking (config.sh redefines SCRIPT_DIR, so source it first)
if [[ -f "$SCRIPTS_PATH/config.sh" ]]; then
    source "$SCRIPTS_PATH/config.sh"
fi
if [[ -f "$SCRIPTS_PATH/utils.sh" ]]; then
    source "$SCRIPTS_PATH/utils.sh"
fi
if [[ -f "$SCRIPTS_PATH/services.sh" ]]; then
    source "$SCRIPTS_PATH/services.sh"
fi
if [[ -f "$SCRIPTS_PATH/bitcoin.sh" ]]; then
    source "$SCRIPTS_PATH/bitcoin.sh"
fi
if [[ -f "$SCRIPTS_PATH/elements.sh" ]]; then
    source "$SCRIPTS_PATH/elements.sh"
fi
if [[ -f "$SCRIPTS_PATH/peerswap.sh" ]]; then
    source "$SCRIPTS_PATH/peerswap.sh"
fi

log_message "Starting background installation check..."

# Function to check if Bitcoin blockchain is fully downloaded
# Usage: check_blockchain_sync "mainnet" or check_blockchain_sync "testnet"
check_blockchain_sync() {
    local network="${1:-mainnet}"  # Default to mainnet if not specified
    local datadir="/data/bitcoin"
    local conf_arg="/data/bitcoin/bitcoin.conf"
    
    # Set the appropriate data directory based on network
    if [ "$network" = "testnet" ]; then
        conf_arg="-testnet"
        log_message "Checking testnet blockchain sync status..."
    else
        log_message "Checking mainnet blockchain sync status..."
    fi
    
    # Check if bitcoin-cli is available
    if ! command -v bitcoin-cli &> /dev/null; then
        log_message "Error: bitcoin-cli not found. Please ensure Bitcoin Core is installed."
        return 1
    fi
    
    # Get blockchain info (run as bitcoin user to access RPC credentials)
    local blockchain_info
    blockchain_info=$(sudo -u bitcoin bitcoin-cli $conf_arg getblockchaininfo 2>&1)
    
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to connect to Bitcoin daemon"
        log_message "$blockchain_info"
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
    log_message "----------------------------------------"
    log_message "Network: $network"
    log_message "Current blocks: $blocks"
    log_message "Total headers: $headers"
    log_message "Sync progress: ${sync_percentage}%"
    log_message "Verification progress: $(awk "BEGIN {printf \"%.2f\", $verification_progress * 100}")%"
    log_message "Initial Block Download: $initial_block_download"
    log_message "----------------------------------------"
    
    # Check if blockchain is fully synced
    if [ "$blocks" = "$headers" ] && [ "$initial_block_download" = "false" ]; then
        log_message "✓ Blockchain is fully synchronized!"
        return 0
    else
        local remaining_blocks=$((headers - blocks))
        log_message "⚠ Blockchain is still syncing... Remaining blocks: $remaining_blocks"
        return 2
    fi
}

check_lnd_sync () {
    local network_choice="$1"

    graphsync=$(sudo -u lnd lncli getinfo --network="$network_choice" 2>/dev/null | grep -oP '"synced_to_graph":\s*\K(true|false)')
    if [ "$graphsync" = "false" ]; then
        log_message "LND graph is fully synchronized!"
        return 0
    else
        log_message "LND graph is still syncing..."
        return 1
    fi
}

# Function to remove cron job
remove_cron_job() {
    log_message "Removing cron job..."
    crontab -l 2>/dev/null | grep -v "install_in_background.sh" | crontab -
    log_message "✓ Cron job removed successfully!"
}

# Main installation orchestration
run_installation() {
    local network_choice="$1"

    # If network not provided, try to detect from bitcoin.conf or lnd.conf
    if [ -z "$network_choice" ]; then
        if grep -q "testnet=1" /data/bitcoin/bitcoin.conf 2>/dev/null; then
            network_choice="testnet"
        else
            network_choice="mainnet"
        fi
    fi

    log_message "Starting background installation for network: $network_choice"

    # Step 1: Install Bitcoin Core if not present
    if ! command -v bitcoin-cli &> /dev/null; then
        log_message "Bitcoin Core not installed. Installing now..."
        export BITCOIN_NETWORK="$network_choice"
        install_complete_stack
        log_message "Bitcoin Core installed. Waiting for service to start..."
        sleep 30
    fi

    check_blockchain_sync "$network_choice"
    local sync_status=$?
    
    if [ $sync_status -eq 0 ]; then
        log_message "Blockchain sync completed successfully, downloading and installing LND..."
        download_lnd

        # Start LND service if not already running
        if ! systemctl is-active --quiet lnd; then
            log_message "Starting LND service..."
            systemctl start lnd
        fi

        # Wait and check if LND is running
        sleep 10
        while ! systemctl is-active --quiet lnd; do
            log_message "Waiting for LND service to start..."
            sleep 5
        done
        log_message "✓ LND service is running"

        # Proceed with further installations (LND will sync in background)
        log_message "Proceeding with Elements, LNDG, PeerSwap, and PSweb installation..."

        # Install Elements Core (required for PeerSwap)
        if ! command -v elementsd &> /dev/null; then
            log_message "Installing Elements Core..."
            install_elements >> "$LOG_FILE" 2>&1
            log_message "✓ Elements binaries installed"

            log_message "Configuring Elements..."
            configure_elements >> "$LOG_FILE" 2>&1
            log_message "✓ Elements configured"

            log_message "Creating Elements systemd service..."
            create_elements_service >> "$LOG_FILE" 2>&1
            log_message "✓ Elements service created"

            # Start Elements service
            log_message "Starting Elements service..."
            systemctl start elementsd

            # Wait for Elements to start
            sleep 10
            while ! systemctl is-active --quiet elementsd; do
                log_message "Waiting for Elements service to start..."
                sleep 5
            done
            log_message "✓ Elements service is running"
        else
            log_message "✓ Elements already installed"
        fi

        log_message "Installing LNDG, PeerSwap, and PSweb..."
        install_lndg >> "$LOG_FILE" 2>&1
        install_peerswap >> "$LOG_FILE" 2>&1
        install_psweb >> "$LOG_FILE" 2>&1
        log_message "✓ All installations completed successfully!"

        # Remove cron job
        remove_cron_job

        # Clean up lock file
        rm -f "$LOCK_FILE"

        log_message "✓ Background installation completed and cron job removed!"
        log_message "ℹ LND will continue syncing in the background"
        exit 0
    else
        log_message "Blockchain not yet synced. Will check again on next cron run."
        exit 0
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

log_message "Background installation monitor started for $NETWORK_CHOICE network"
run_installation "$NETWORK_CHOICE"

# ============================================================================
# RESUMO DO SCRIPT INSTALL_IN_BACKGROUND.SH
# ============================================================================
#
# DESCRIÇÃO:
# - Script para monitorar sincronização do blockchain via CRON e executar
#   instalações (LND, Elements, LNDG, PeerSwap, PSweb) quando estiver pronto.
#
# FUNCIONALIDADES:
# - check_blockchain_sync(): Verificação periódica via cron (a cada hora)
# - run_installation(): Acionamento automático das instalações
# - Instala: LND → Elements → LNDG → PeerSwap → PSweb
# - Lock file para evitar múltiplas instâncias
# - Auto-remoção do cron job quando concluir
# - Log detalhado em /var/log/brln-background-install.log
#
# ============================================================================
