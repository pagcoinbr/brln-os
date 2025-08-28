#!/bin/bash

# LND Debug Entrypoint Script
# This script allows you to investigate authorization and startup issues

set -e

echo "=== LND Debug Mode ==="
echo "Container started at: $(date)"
echo "Current user: $(whoami)"
echo "User ID: $(id)"
echo "Working directory: $(pwd)"
echo "Environment variables:"
env | grep -E "(LND|DATA|USER)" | sort
echo ""

echo "=== Directory Permissions ==="
echo "LND data directory:"
ls -la /data/lnd/ || echo "Cannot access /data/lnd/"
echo ""
echo "Tor data directory:"
ls -la /var/lib/tor/ || echo "Cannot access /var/lib/tor/"
echo ""

echo "=== Configuration Files ==="
echo "LND Config file:"
if [ -f "/data/lnd/lnd.conf" ]; then
    echo "Config file exists and is readable"
    head -10 /data/lnd/lnd.conf
else
    echo "Config file not found or not readable"
fi
echo ""

echo "Password file:"
if [ -f "/data/lnd/password.txt" ]; then
    echo "Password file exists and is readable"
else
    echo "Password file not found or not readable"
fi
echo ""

echo "=== Network Connectivity ==="
echo "Checking connectivity to tor..."
timeout 5 bash -c 'cat < /dev/null > /dev/tcp/tor/9050' && echo "Tor is reachable" || echo "Cannot reach tor:9050"
echo ""

echo "=== Available Commands ==="
echo "You can now exec into this container and run:"
echo "  docker exec -it lnd bash"
echo "  - Check permissions: ls -la /data/lnd/"
echo "  - Test LND: lnd --help"
echo "  - Start LND manually: lnd --configfile=/data/lnd/lnd.conf --datadir=/data/lnd"
echo ""

echo "Sleeping for debugging... (Press Ctrl+C to exit or set DEBUG_SLEEP_TIME env var)"
SLEEP_TIME=${DEBUG_SLEEP_TIME:-3600}
echo "Sleeping for ${SLEEP_TIME} seconds..."
sleep ${SLEEP_TIME}
