#!/bin/bash

# Configuration and Environment Variables
SCRIPT_VERSION=v1.0-beta
TOR_LINIK=https://deb.torproject.org/torproject.org
TOR_GPGLINK=https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc
I2P_REPO_HELPER=https://repo.i2pd.xyz/.help/add_repo

# Network selection: mainnet or testnet
BITCOIN_NETWORK=${BITCOIN_NETWORK:-mainnet}

# Bitcoin backend configuration (local or remote)
BITCOIN_BACKEND_CONFIG=${BITCOIN_BACKEND_CONFIG:-/data/brln-config/bitcoin-backend.env}
if [[ -f "$BITCOIN_BACKEND_CONFIG" ]]; then
  # shellcheck source=/dev/null
  source "$BITCOIN_BACKEND_CONFIG"
fi

BITCOIN_BACKEND=${BITCOIN_BACKEND:-local}
BITCOIN_PRUNED=${BITCOIN_PRUNED:-0}
BITCOIN_PRUNE_SIZE=${BITCOIN_PRUNE_SIZE:-550}
BITCOIN_RPC_HOST=${BITCOIN_RPC_HOST:-127.0.0.1}
BITCOIN_RPC_PORT=${BITCOIN_RPC_PORT:-8332}
BITCOIN_RPC_USER=${BITCOIN_RPC_USER:-minibolt}
BITCOIN_RPC_PASSWORD=${BITCOIN_RPC_PASSWORD:-}
BITCOIN_ZMQ_BLOCK=${BITCOIN_ZMQ_BLOCK:-tcp://127.0.0.1:28332}
BITCOIN_ZMQ_TX=${BITCOIN_ZMQ_TX:-tcp://127.0.0.1:28333}

LND_VERSION=0.20.0
BTC_VERSION=30.0

# Smart path detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_REPO_DIR="$HOME/brlnfullauto"
if [[ -d "$DEFAULT_REPO_DIR" ]]; then
  REPO_DIR="$DEFAULT_REPO_DIR"
else
  REPO_DIR="$SCRIPT_DIR"
fi

FRONTEND_DIR="$REPO_DIR/frontend"
if [[ -d "$REPO_DIR/services" ]]; then
  SERVICES_DIR="$REPO_DIR/services"
else
  SERVICES_DIR="$HOME/brlnfullauto/services"
fi

LOCAL_APPS_DIR=""
for candidate in "$REPO_DIR/local_apps" "$REPO_DIR/localApps" \
                 "$HOME/brlnfullauto/local_apps"; do
  if [[ -d "$candidate" ]]; then
    LOCAL_APPS_DIR="$candidate"
    break
  fi
done
LOCAL_APPS_DIR="${LOCAL_APPS_DIR:-$HOME/brlnfullauto/local_apps}"

POETRY_BIN="$HOME/.local/bin/poetry"
FLASKVENV_DIR="$HOME/envflask"
atual_user=$(whoami)
branch=main
git_user=pagcoinbr

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
GRAY='\033[1;30m'
NC='\033[0m' # No color

# Architecture detection
arch=$(uname -m)
case $arch in
  x86_64) arch="x86_64" ;;
  aarch64|arm64) arch="arm64" ;;
  armv7l) arch="arm" ;;
  *) echo "Unsupported architecture: $arch"; exit 1 ;;
esac

# Network detection
get_network_cidr() {
  local interface=$(ip route show default | awk '/default/ { print $5 }' | head -n 1)
  local ip=$(ip addr show $interface | awk '/inet / { print $2 }' | head -n 1)
  echo $ip | cut -d'/' -f1 | awk -F'.' '{print $1"."$2"."$3".0/24"}'
}

subnet=$(get_network_cidr)
