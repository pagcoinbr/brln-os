#!/bin/bash
source /home/admin/brlnfullauto/shell/.env.sh
# BRLNFullauto: PeerSwap Web UI installation and management script
#
# This script installs and manages PeerSwap Web UI to provide a graphical
# interface for PeerSwap submarine swaps between LND and Liquid

set -e

# Determine system architecture
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "armv7l" ]; then
  ARCH_TYPE="arm64"
else
  ARCH_TYPE="amd64"
fi

# Function to check if PeerSwap is installed
check_peerswap_installed() {
  if [ ! -f "$PEERSWAP_CONF" ] || ! command -v pscli &> /dev/null; then
    echo "⚠️  PeerSwap is not installed. PeerSwap Web UI requires PeerSwap to function properly."
    read -p "Would you like to install PeerSwap first? (y/n): " install_ps
    if [[ "$install_ps" == "y" ]]; then
      echo "Installing PeerSwap..."
      bash "$(dirname "$0")/peerswap.sh" install
    else
      echo "Cannot proceed without PeerSwap. Exiting..."
      exit 1
    fi
  fi
}

# Function to check if Elements Core is installed
check_elements_installed() {
  if ! command -v elements-cli &> /dev/null; then
    echo "⚠️  Elements Core is not installed. PeerSwap Web UI requires Elements Core for L-BTC swaps."
    read -p "Would you like to install Elements Core now? (y/n): " install_elements
    if [[ "$install_elements" == "y" ]]; then
      echo "Installing Elements Core..."
      # You may need to adjust this path if your elements installation script is elsewhere
      bash "$(dirname "$0")/../nodes/elementsd.sh" install
    else
      echo "Continuing without Elements Core. Some features may not work."
    fi
  fi
}

# Function to open required firewall ports
configure_firewall() {
  echo "Configuring firewall for PeerSwap Web UI..."
  
  # Check if UFW is installed and active
  if command -v ufw &> /dev/null && sudo ufw status | grep -q "active"; then
    # Allow access to PeerSwap Web UI port from the local network
    sudo ufw allow from 192.168.0.0/16 to any port $PSWEB_PORT proto tcp comment 'PeerSwap Web UI'
    echo "Firewall configured to allow access to port $PSWEB_PORT from local network"
  else
    echo "UFW not installed or not active. Skipping firewall configuration."
  fi
}

# Function to install PeerSwap Web UI
install_psweb() {
  echo "Installing PeerSwap Web UI..."
  
  # Check dependencies
  check_peerswap_installed
  check_elements_installed

  # Ensure PeerSwap directory exists
  mkdir -p "$PEERSWAP_DIR"

  # Clone and build PeerSwap Web UI
  echo "Building PeerSwap Web UI from source..."
  sudo tar -xvzf /home/admin/brlnfullauto/local_apps/psweb/peerswap-web-$PSWEB_VERSION.tar.gz -C /home/admin/brlnfullauto/local_apps/psweb
  cd /home/admin/brlnfullauto/local_apps/psweb/peerswap-web-$PSWEB_VERSION
  make -j$(nproc) install-lnd

  # Create service file for systemd
  create_service_file

  # Configure firewall
  configure_firewall

  echo "PeerSwap Web UI installation complete!"
  echo "Run 'peerswapweb.sh start' to start the service."
  echo "Once started, you can access PeerSwap Web UI at: http://$(hostname -I | awk '{print $1}'):$PSWEB_PORT"
}

# Function to create PeerSwap Web UI systemd service file
create_service_file() {
  echo "Creating PeerSwap Web UI service file..."
  sudo cp /home/admin/brlnfullauto/services/psweb.service $PSWEB_SERVICE
  sudo systemctl daemon-reload
  echo "Service file created at $PSWEB_SERVICE"
}

