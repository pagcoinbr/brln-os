#!/bin/bash

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

# Global variables
PEERSWAP_DIR="/home/admin/.peerswap"
PEERSWAP_CONF="$PEERSWAP_DIR/peerswap.conf"
PSWEB_CONFIG="$PEERSWAP_DIR/pswebconfig.json"
PSWEB_VERSION="latest"
PSWEB_SERVICE="/etc/systemd/system/psweb.service"
PSWEB_PORT="1984"

# Function to display help information
show_help() {
  echo "PeerSwap Web UI - Web Interface for PeerSwap"
  echo
  echo "Usage: peerswapweb.sh [OPTION]"
  echo
  echo "Options:"
  echo "  install    - Install PeerSwap Web UI"
  echo "  status     - Check PeerSwap Web UI status"
  echo "  start      - Start PeerSwap Web UI"
  echo "  stop       - Stop PeerSwap Web UI"
  echo "  restart    - Restart PeerSwap Web UI"
  echo "  update     - Update PeerSwap Web UI"
  echo "  menu       - Show interactive menu"
  echo "  help       - Show this help"
}

# Function to check if PeerSwap Web UI is running
is_psweb_running() {
  if pgrep -f psweb > /dev/null; then
    return 0
  else
    return 1
  fi
}

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

# Function to install Go
install_golang() {
  echo "Installing Go..."
  
  # Determine Go tarball based on architecture
  if [ "$ARCH_TYPE" = "arm64" ]; then
    GO_TARBALL="go1.24.3.linux-arm64.tar.gz"
  else
    GO_TARBALL="go1.24.3.linux-amd64.tar.gz"
  fi

  # Check if we have the Go tarball locally
  GO_TARBALL_PATH="/home/admin/brlnfullauto/local_apps/golang/$GO_TARBALL"
  
  # Download or use local Go tarball
  if [ -f "$GO_TARBALL_PATH" ]; then
    echo "Using local Go installation package..."
    sudo tar -C /usr/local -xzf "$GO_TARBALL_PATH"
  else
    echo "Downloading Go from golang.org..."
    cd /tmp
    wget "https://go.dev/dl/$GO_TARBALL"
    sudo tar -C /usr/local -xzf "$GO_TARBALL"
  fi
  
  # Set Go environment variables
  export PATH=$PATH:/usr/local/go/bin
  export GOPATH=$HOME/go
  export PATH=$PATH:$GOPATH/bin
  
  # Add Go to the PATH permanently
  if ! grep -q "export PATH=\$PATH:/usr/local/go/bin" "$HOME/.profile"; then
    echo "export PATH=\$PATH:/usr/local/go/bin" >> "$HOME/.profile"
    echo "export GOPATH=\$HOME/go" >> "$HOME/.profile"
    echo "export PATH=\$PATH:\$GOPATH/bin" >> "$HOME/.profile"
  fi
  
  # Ensure Go binaries directory exists
  mkdir -p "$HOME/go/bin"
  
  echo "Go installation complete!"
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

  # Ensure PeerSwap directory exists
  mkdir -p "$PEERSWAP_DIR"

  # Clone and build PeerSwap Web UI
  echo "Building PeerSwap Web UI from source..."
  cd /tmp
  rm -rf peerswap-web
  git clone https://github.com/Impa10r/peerswap-web
  cd peerswap-web
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
  
  sudo tee $PSWEB_SERVICE > /dev/null << EOF
[Unit]
Description=PeerSwap Web UI
After=lnd.service elementsd.service peerswap.service
Requires=lnd.service

[Service]
ExecStart=/home/admin/go/bin/psweb
User=admin
Group=admin
Type=simple
KillMode=process
TimeoutSec=180
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  echo "Service file created at $PSWEB_SERVICE"
}

# Function to start PeerSwap Web UI
start_psweb() {
  if is_psweb_running; then
    echo "PeerSwap Web UI is already running"
  else
    echo "Starting PeerSwap Web UI..."
    sudo systemctl start psweb
    sleep 2
    if is_psweb_running; then
      echo "PeerSwap Web UI started successfully"
      echo "You can access it at: http://$(hostname -I | awk '{print $1}'):$PSWEB_PORT"
    else
      echo "Failed to start PeerSwap Web UI"
    fi
  fi
}

# Function to stop PeerSwap Web UI
stop_psweb() {
  if is_psweb_running; then
    echo "Stopping PeerSwap Web UI..."
    sudo systemctl stop psweb
    sleep 2
    if ! is_psweb_running; then
      echo "PeerSwap Web UI stopped successfully"
    else
      echo "Failed to stop PeerSwap Web UI"
    fi
  else
    echo "PeerSwap Web UI is not running"
  fi
}

# Function to restart PeerSwap Web UI
restart_psweb() {
  echo "Restarting PeerSwap Web UI..."
  stop_psweb
  sleep 2
  start_psweb
}

# Function to update PeerSwap Web UI
update_psweb() {
  echo "Updating PeerSwap Web UI..."
  
  # Stop the service first
  stop_psweb
  
  # Clone and build the latest version
  cd /tmp
  rm -rf peerswap-web
  git clone https://github.com/Impa10r/peerswap-web
  cd peerswap-web
  make -j$(nproc) install-lnd
  
  echo "PeerSwap Web UI updated to the latest version!"
  
  # Start the service again
  start_psweb
}

# Function to check PeerSwap Web UI status
check_status() {
  echo "Checking PeerSwap Web UI status..."
  
  if is_psweb_running; then
    echo "PeerSwap Web UI is running"
    echo "You can access it at: http://$(hostname -I | awk '{print $1}'):$PSWEB_PORT"
    
    # Check service status
    sudo systemctl status psweb
  else
    echo "PeerSwap Web UI is not running"
    echo "Run 'peerswapweb.sh start' to start the service"
  fi
}

# Function to display interactive menu
show_menu() {
  while true; do
    echo "======= PeerSwap Web UI Menu ======="
    echo "1. Install PeerSwap Web UI"
    echo "2. Start PeerSwap Web UI"
    echo "3. Stop PeerSwap Web UI"
    echo "4. Restart PeerSwap Web UI"
    echo "5. Check Status"
    echo "6. Update PeerSwap Web UI"
    echo "7. Exit"
    echo "=================================="
    
    read -p "Choose an option [1-7]: " choice
    
    case $choice in
      1) install_psweb ;;
      2) start_psweb ;;
      3) stop_psweb ;;
      4) restart_psweb ;;
      5) check_status ;;
      6) update_psweb ;;
      7) exit 0 ;;
      *) echo "Invalid option" ;;
    esac
    
    echo "Press Enter to continue..."
    read
  done
}

# Main script execution
if [ $# -eq 0 ]; then
  show_menu
else
  case $1 in
    "install") install_psweb ;;
    "status") check_status ;;
    "start") start_psweb ;;
    "stop") stop_psweb ;;
    "restart") restart_psweb ;;
    "update") update_psweb ;;
    "menu") show_menu ;;
    "help"|*) show_help ;;
  esac
fi

exit 0
