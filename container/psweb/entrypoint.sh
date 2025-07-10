#!/bin/sh

echo "Starting PeerSwap Web UI..."

# Check if config file exists, if not copy from example
if [ ! -f "/home/psweb/.peerswap/pswebconfig.json" ]; then
  echo "Config file not found, using default configuration..."
  cp /home/psweb/.peerswap/pswebconfig.json.example /home/psweb/.peerswap/pswebconfig.json
fi

# Wait for LND TLS certificate to be available
echo "Waiting for LND TLS certificate..."
while [ ! -f "/home/lnd/.lnd/tls.cert" ]; do
  echo "TLS certificate not found, waiting 5 seconds..."
  sleep 5
done

echo "TLS certificate found, starting psweb..."

# Start psweb
exec psweb --datadir /home/psweb/.peerswap
