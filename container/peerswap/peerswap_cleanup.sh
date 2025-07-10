#!/bin/bash

# PeerSwap Cleanup Script
# This script cleans up peerswap wallet data and resolves database conflicts

set -e

echo "PeerSwap Cleanup Script Started..."

# Configuration
ELEMENTS_RPC_USER="elementsuser"
ELEMENTS_RPC_PASS="elementspassword123"
ELEMENTS_RPC_HOST="elements"
ELEMENTS_RPC_PORT="7041"
WALLET_NAME="peerswap"

# Function to execute elements-cli commands through Docker
elements_cli() {
    docker exec elements elements-cli -rpcuser="$ELEMENTS_RPC_USER" -rpcpassword="$ELEMENTS_RPC_PASS" "$@"
}

# Function to check if Elements daemon is running
check_elements_daemon() {
    echo "Checking if Elements daemon is accessible..."
    if ! elements_cli getblockchaininfo >/dev/null 2>&1; then
        echo "ERROR: Elements daemon is not accessible. Make sure Elements container is running."
        exit 1
    fi
    echo "Elements daemon is accessible."
}

# Function to cleanup peerswap wallet
cleanup_peerswap_wallet() {
    echo "Cleaning up peerswap wallet..."
    
    # Try to unload the wallet first (ignore errors if wallet is not loaded)
    echo "Attempting to unload peerswap wallet..."
    elements_cli unloadwallet "$WALLET_NAME" 2>/dev/null || echo "Wallet was not loaded or already unloaded"
    
    # List current wallets
    echo "Current wallets:"
    elements_cli listwallets || echo "Failed to list wallets"
    
    # Check if wallet directory exists and remove it
    echo "Checking for wallet database directory..."
    
    # The wallet directory is typically in the Elements data directory
    # Since we're running in containers, we need to clean it from the Elements container
    # We'll use a different approach - try to create the wallet and handle the error
    
    echo "Attempting to remove existing wallet files..."
    
    # Method 1: Try to use Elements CLI to handle the cleanup
    # First, let's try to load the wallet to see its state
    if elements_cli loadwallet "$WALLET_NAME" 2>/dev/null; then
        echo "Wallet loaded successfully, unloading it again..."
        elements_cli unloadwallet "$WALLET_NAME"
    fi
    
    # Method 2: Try to backup and remove the wallet
    echo "Attempting to backup and remove the problematic wallet..."
    if elements_cli backupwallet "$WALLET_NAME" "/tmp/peerswap_backup_$(date +%Y%m%d_%H%M%S).dat" 2>/dev/null; then
        echo "Wallet backed up successfully"
    else
        echo "Could not backup wallet (this might be normal if wallet is corrupted)"
    fi
    
    echo "Peerswap wallet cleanup completed."
}

# Function to recreate peerswap wallet
recreate_peerswap_wallet() {
    echo "Recreating peerswap wallet..."
    
    # Wait a moment for any cleanup to settle
    sleep 2
    
    # Try to create the wallet
    if elements_cli createwallet "$WALLET_NAME" false false "" false false 2>/dev/null; then
        echo "Peerswap wallet created successfully!"
        
        # Verify wallet creation
        if elements_cli getwalletinfo -rpcwallet="$WALLET_NAME" >/dev/null 2>&1; then
            echo "Wallet verification successful!"
            return 0
        else
            echo "WARNING: Wallet created but verification failed"
            return 1
        fi
    else
        echo "Failed to create wallet, checking if it already exists..."
        
        # Try to load existing wallet
        if elements_cli loadwallet "$WALLET_NAME" 2>/dev/null; then
            echo "Existing wallet loaded successfully!"
            return 0
        else
            echo "ERROR: Could not create or load peerswap wallet"
            return 1
        fi
    fi
}

# Function to clean Elements data directory (more aggressive cleanup)
aggressive_cleanup() {
    echo "Performing aggressive cleanup..."
    echo "WARNING: This will remove the peerswap wallet database directory entirely!"
    read -p "Are you sure you want to continue? This will delete all peerswap wallet data! (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Executing aggressive cleanup..."
        
        # This approach requires access to the Elements container's filesystem
        # We'll need to execute this from the host or inside the Elements container
        echo "Please run the following command on the host system or inside the Elements container:"
        echo "sudo rm -rf /home/elements/.elements/liquidv1/peerswap/"
        echo "OR"
        echo "docker exec elements rm -rf /home/elements/.elements/liquidv1/peerswap/"
        echo ""
        echo "After running the above command, try recreating the wallet again."
    else
        echo "Aggressive cleanup cancelled."
    fi
}

# Main cleanup function
main() {
    echo "Starting PeerSwap cleanup process..."
    
    # Check if Elements daemon is accessible
    check_elements_daemon
    
    # Cleanup existing wallet
    cleanup_peerswap_wallet
    
    # Try to recreate the wallet
    if recreate_peerswap_wallet; then
        echo "✓ PeerSwap wallet cleanup and recreation completed successfully!"
        exit 0
    else
        echo "✗ Standard cleanup failed. You may need aggressive cleanup."
        echo ""
        echo "Options:"
        echo "1. Try running this script again"
        echo "2. Run aggressive cleanup (will delete all wallet data)"
        echo "3. Restart the Elements container and try again"
        echo ""
        
        read -p "Do you want to try aggressive cleanup? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            aggressive_cleanup
        fi
        
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    "aggressive"|"--aggressive"|"-a")
        echo "Running aggressive cleanup mode..."
        check_elements_daemon
        aggressive_cleanup
        ;;
    "wallet-only"|"--wallet-only"|"-w")
        echo "Running wallet-only cleanup..."
        check_elements_daemon
        cleanup_peerswap_wallet
        recreate_peerswap_wallet
        ;;
    "help"|"--help"|"-h")
        echo "PeerSwap Cleanup Script"
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  (no args)     Standard cleanup and wallet recreation"
        echo "  aggressive    Aggressive cleanup - removes wallet database directory"
        echo "  wallet-only   Only cleanup and recreate wallet, no aggressive options"
        echo "  help          Show this help message"
        echo ""
        echo "This script helps resolve PeerSwap wallet database conflicts."
        ;;
    *)
        main
        ;;
esac