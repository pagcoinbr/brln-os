#!/bin/bash
source /home/admin/brlnfullauto/shell/.env
# BRLNFullauto: PeerSwap installation and management script
#
# This script installs and manages PeerSwap to facilitate
# submarine swaps between LND and Liquid

set -e

# Determine system architecture
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "armv7l" ]; then
  ARCH_TYPE="arm64"
else
  ARCH_TYPE="amd64"
fi

# Function to install PeerSwap
install_peerswap() {
  echo "Installing PeerSwap..."
  
  # Check if Go is installed
  if ! command -v go &> /dev/null; then
    echo "Go is required but not installed."
    read -p "Would you like to install Go now? (y/n): " install_go
    if [[ "$install_go" == "y" ]]; then
      install_golang
    else
      echo "Cannot proceed without Go. Exiting..."
      exit 1
    fi
  fi

  # Create PeerSwap directories
  mkdir -p "$PEERSWAP_DIR"

  # Check if we have the tarball, otherwise build from source
  if [ -f "$PEERSWAP_TARBALL_PATH" ]; then
    echo "Installing PeerSwap from provided package..."
    cd /tmp
    tar -xvzf "$PEERSWAP_TARBALL_PATH"
    cd /home/admin/brlnfullauto/local_apps/peerswap/peerswap-$PEERSWAP_VERSION
    sudo apt update -y
    sudo apt install make -y
    sudo apt install -y build-essential autoconf libtool pkg-config
    mkdir -p ~/.peerswap
    make lnd-release
    # Install binaries to /usr/local/bin
    sudo cp ~/go/bin/peerswapd ~/go/bin/pscli /usr/local/bin/
    sudo chmod +x /usr/local/bin/peerswapd /usr/local/bin/pscli

  # Create config file if it doesn't exist
  if [ ! -f "$PEERSWAP_CONF" ]; then
    create_config_file
  fi

  # Create service file for systemd
  create_service_file

  echo "PeerSwap installation complete!"
  echo "Run 'peerswap.sh start' to start the daemon."
}

# Function to create PeerSwap config file
create_config_file() {
  echo "Creating PeerSwap configuration file..."
  sudo cp /home/admin/brlnfullauto/local_apps/peerswap/peerswap.conf $PEERSWAP_CONF
  echo "Configuration file created at $PEERSWAP_CONF"
}

# Function to create PeerSwap systemd service file
create_service_file() {
  echo "Creating PeerSwap service file..."
  sudo cp /home/admin/brlnfullauto/local_apps/peerswap/peerswap.service /etc/systemd/system/
  sudo systemctl daemon-reload
  echo "Service file created at /etc/systemd/system/peerswap.service"
}

install_peerswap