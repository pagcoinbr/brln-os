#!/bin/bash
set -e

# Wait for Elements to be ready
echo "Waiting for Elements daemon to be ready..."
while ! elements-cli -rpcconnect=elements -rpcport=7041 -rpcuser=elementsuser -rpcpassword=elementspassword123 getblockchaininfo >/dev/null 2>&1; do
    echo "Elements daemon not ready yet, waiting 5 seconds..."
    sleep 5
done

echo "Elements daemon is ready!"

# Check if peerswap wallet already exists
WALLET_EXISTS=$(elements-cli -rpcconnect=elements -rpcport=7041 -rpcuser=elementsuser -rpcpassword=elementspassword123 listwallets | grep -c "peerswap" || true)

# Function to handle wallet creation/loading
handle_peerswap_wallet() {
    echo "Handling peerswap wallet setup..."
    
    # First, try to load the wallet if it exists
    if elements-cli -rpcconnect=elements -rpcport=7041 -rpcuser=elementsuser -rpcpassword=elementspassword123 loadwallet "peerswap" 2>/dev/null; then
        echo "Peerswap wallet loaded successfully!"
        return 0
    fi
    
    # If loading failed, try to create the wallet
    echo "Attempting to create peerswap wallet..."
    if elements-cli -rpcconnect=elements -rpcport=7041 -rpcuser=elementsuser -rpcpassword=elementspassword123 createwallet "peerswap" false false "" false false 2>/dev/null; then
        echo "Peerswap wallet created successfully!"
        return 0
    else
        echo "Wallet creation failed, checking if wallet directory exists..."
        
        # If creation failed due to existing directory, try to load it again
        echo "Attempting to load existing wallet after creation failure..."
        if elements-cli -rpcconnect=elements -rpcport=7041 -rpcuser=elementsuser -rpcpassword=elementspassword123 loadwallet "peerswap" 2>/dev/null; then
            echo "Existing peerswap wallet loaded successfully!"
            return 0
        else
            echo "ERROR: Could not create or load peerswap wallet"
            echo "This might indicate a corrupted wallet. Please run the cleanup script."
            exit 1
        fi
    fi
}

# Handle wallet setup
handle_peerswap_wallet

# Start PeerSwap daemon
echo "Starting PeerSwap daemon..."
exec peerswapd --configfile=/home/peerswap/.peerswap/peerswap.conf "$@"
