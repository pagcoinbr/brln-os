#!/bin/sh

echo "Starting PeerSwap Web UI..."

# Check if config file exists, if not copy from example
if [ ! -f "/home/psweb/.peerswap/pswebconfig.json" ]; then
  echo "Config file not found, using default configuration..."
  cp /home/psweb/.peerswap/pswebconfig.json.example /home/psweb/.peerswap/pswebconfig.json
fi

# Start psweb
exec psweb --datadir /home/psweb/.peerswap/pswebconfig.json
