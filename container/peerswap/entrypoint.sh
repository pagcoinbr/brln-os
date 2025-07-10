#!/bin/bash
set -e

# Wait for Elements to be ready
echo "Waiting for Elements daemon to be ready..."
while ! elements-cli -rpcconnect=elements -rpcport=7041 -rpcuser=elementsuser -rpcpassword=elementspassword123 getblockchaininfo >/dev/null 2>&1; do
    echo "Elements daemon not ready yet, waiting 5 seconds..."
    sleep 5
done

echo "Elements daemon is ready!"

# Verify that peerswap wallet is available
echo "Verifying peerswap wallet availability..."
WALLET_EXISTS=$(elements-cli -rpcconnect=elements -rpcport=7041 -rpcuser=elementsuser -rpcpassword=elementspassword123 listwallets | grep -c "peerswap" || true)

if [ "$WALLET_EXISTS" -eq 0 ]; then
    echo "ERRO: Carteira peerswap não encontrada!"
    echo "A carteira deveria ter sido criada pelo Elements daemon."
    echo "Verifique os logs do Elements para mais detalhes."
    exit 1
fi

echo "Peerswap wallet is available!"

# Start PeerSwap daemon
echo "Starting PeerSwap daemon..."
exec peerswapd --config.file=/home/peerswap/.peerswap/peerswap.conf "$@"
