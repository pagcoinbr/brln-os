#!/bin/bash

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

# Global variables
PEERSWAP_DIR="/home/admin/.peerswap"
PEERSWAP_CONF="$PEERSWAP_DIR/peerswap.conf"
POLICY_CONF="$PEERSWAP_DIR/policy.conf"
PEERSWAP_VERSION="5.0.0-rc2"
PEERSWAP_TARBALL="peerswap-$PEERSWAP_VERSION.tar.gz"
PEERSWAP_TARBALL_PATH="/home/admin/brlnfullauto/local_apps/peerswap/$PEERSWAP_TARBALL"

# Function to display help information
show_help() {
  echo "PeerSwap - Submarine Swap Tool for LND & Liquid"
  echo
  echo "Usage: peerswap.sh [OPTION]"
  echo
  echo "Options:"
  echo "  install    - Install PeerSwap daemon"
  echo "  status     - Check PeerSwap status"
  echo "  start      - Start PeerSwap daemon"
  echo "  stop       - Stop PeerSwap daemon"
  echo "  restart    - Restart PeerSwap daemon"
  echo "  addpeer    - Add a peer to the allowlist"
  echo "  listpeers  - List configured peers"
  echo "  menu       - Show interactive menu"
  echo "  help       - Show this help"
}

# Function to check if PeerSwap is running
is_peerswap_running() {
  if pgrep -f peerswapd > /dev/null; then
    return 0
  else
    return 1
  fi
}

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
    tar -xzf "$PEERSWAP_TARBALL_PATH"
    cd peerswap-$PEERSWAP_VERSION
    # Install binaries to /usr/local/bin
    sudo cp peerswapd pscli /usr/local/bin/
    sudo chmod +x /usr/local/bin/peerswapd /usr/local/bin/pscli
  else
    echo "Building PeerSwap from source..."
    cd /tmp
    git clone https://github.com/ElementsProject/peerswap.git
    cd peerswap
    make lnd-release
    # The binaries should now be in GOPATH/bin
    if [ -f "$GOPATH/bin/peerswapd" ] && [ -f "$GOPATH/bin/pscli" ]; then
      sudo cp "$GOPATH/bin/peerswapd" "$GOPATH/bin/pscli" /usr/local/bin/
      sudo chmod +x /usr/local/bin/peerswapd /usr/local/bin/pscli
    else
      # If not in GOPATH, try the current directory
      if [ -f "./peerswapd" ] && [ -f "./pscli" ]; then
        sudo cp ./peerswapd ./pscli /usr/local/bin/
        sudo chmod +x /usr/local/bin/peerswapd /usr/local/bin/pscli
      else
        echo "Error: Could not find peerswapd and pscli binaries"
        exit 1
      fi
    fi
  fi

  # Create config file if it doesn't exist
  if [ ! -f "$PEERSWAP_CONF" ]; then
    create_config_file
  fi

  # Create service file for systemd
  create_service_file

  echo "PeerSwap installation complete!"
  echo "Run 'peerswap.sh start' to start the daemon."
}

# Function to install Golang
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

# Function to create PeerSwap config file
create_config_file() {
  echo "Creating PeerSwap configuration file..."

  # Extract RPC user and pass from elements.conf
  local ELEMENTS_CONF="/home/admin/brlnfullauto/conf_files/elements.conf"
  local RPC_USER=$(grep -w "rpcuser" "$ELEMENTS_CONF" | cut -d '=' -f2)
  local RPC_PASS=$(grep -w "rpcpassword" "$ELEMENTS_CONF" | cut -d '=' -f2)
  local RPC_PORT=$(grep -w "rpcport" "$ELEMENTS_CONF" | cut -d '=' -f2)

  # Create L-BTC only config
  cat <<EOF > "$PEERSWAP_CONF"
bitcoinswaps=false # disables BTC swaps
lnd.tlscertpath=/home/admin/.lnd/tls.cert
lnd.macaroonpath=/home/admin/.lnd/data/chain/bitcoin/mainnet/admin.macaroon
elementsd.rpcuser=$RPC_USER
elementsd.rpcpass=$RPC_PASS
elementsd.rpchost=http://127.0.0.1 # the http:// is mandatory
elementsd.rpcport=$RPC_PORT
elementsd.rpcwallet=peerswap
EOF

  echo "Configuration file created at $PEERSWAP_CONF"
}

# Function to create PeerSwap systemd service file
create_service_file() {
  echo "Creating PeerSwap service file..."
  
  sudo cat <<EOF > /etc/systemd/system/peerswap.service
[Unit]
Description=PeerSwap Daemon
After=lnd.service elementsd.service
Requires=lnd.service elementsd.service

[Service]
ExecStart=/usr/local/bin/peerswapd
User=admin
Group=admin
Type=simple
TimeoutSec=120
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  echo "Service file created at /etc/systemd/system/peerswap.service"
}

# Function to start PeerSwap daemon
start_peerswap() {
  if is_peerswap_running; then
    echo "PeerSwap is already running"
  else
    echo "Starting PeerSwap..."
    sudo systemctl start peerswap
    sleep 2
    if is_peerswap_running; then
      echo "PeerSwap started successfully"
    else
      echo "Failed to start PeerSwap"
    fi
  fi
}

# Function to stop PeerSwap daemon
stop_peerswap() {
  if is_peerswap_running; then
    echo "Stopping PeerSwap..."
    sudo systemctl stop peerswap
    sleep 2
    if ! is_peerswap_running; then
      echo "PeerSwap stopped successfully"
    else
      echo "Failed to stop PeerSwap"
    fi
  else
    echo "PeerSwap is not running"
  fi
}

# Function to restart PeerSwap daemon
restart_peerswap() {
  echo "Restarting PeerSwap..."
  stop_peerswap
  sleep 2
  start_peerswap
}

# Function to check PeerSwap status
check_status() {
  echo "Checking PeerSwap status..."
  
  if is_peerswap_running; then
    echo "PeerSwap daemon is running"
    
    # Check service status
    sudo systemctl status peerswap
    
    # Display PeerSwap info
    echo "PeerSwap Information:"
    if command -v pscli &> /dev/null; then
      pscli getinfo
      echo "Policy:"
      pscli listpeers
    else
      echo "pscli command not found"
    fi
  else
    echo "PeerSwap daemon is not running"
  fi
}

# Function to add a peer to the allowlist
add_peer() {
  if [ -z "$1" ]; then
    read -p "Enter peer public key: " PEER_PUBKEY
  else
    PEER_PUBKEY="$1"
  fi
  
  if [ -z "$PEER_PUBKEY" ]; then
    echo "No public key provided. Exiting..."
    return 1
  fi
  
  echo "Adding peer $PEER_PUBKEY to allowlist..."
  if command -v pscli &> /dev/null; then
    pscli addpeer "$PEER_PUBKEY"
    echo "Peer added successfully"
  else
    echo "pscli command not found. Manual configuration required:"
    echo "Add 'allowlisted_peers=$PEER_PUBKEY' to $POLICY_CONF"
  fi
}

# Function to list configured peers
list_peers() {
  echo "Listing configured peers..."
  if command -v pscli &> /dev/null; then
    pscli listpeers
  else
    echo "pscli command not found"
    if [ -f "$POLICY_CONF" ]; then
      echo "Content of $POLICY_CONF:"
      cat "$POLICY_CONF"
    else
      echo "Policy file not found"
    fi
  fi
}

# Function to display interactive menu
show_menu() {
  while true; do
    echo "======= PeerSwap Menu ======="
    echo "1. Install PeerSwap"
    echo "2. Start PeerSwap"
    echo "3. Stop PeerSwap"
    echo "4. Restart PeerSwap"
    echo "5. Check Status"
    echo "6. Add Peer to Allowlist"
    echo "7. List Configured Peers"
    echo "8. Exit"
    echo "============================"
    
    read -p "Choose an option [1-8]: " choice
    
    case $choice in
      1) install_peerswap ;;
      2) start_peerswap ;;
      3) stop_peerswap ;;
      4) restart_peerswap ;;
      5) check_status ;;
      6) 
        read -p "Enter peer public key: " peer
        add_peer "$peer"
        ;;
      7) list_peers ;;
      8) exit 0 ;;
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
    "install") install_peerswap ;;
    "status") check_status ;;
    "start") start_peerswap ;;
    "stop") stop_peerswap ;;
    "restart") restart_peerswap ;;
    "addpeer") add_peer "$2" ;;
    "listpeers") list_peers ;;
    "menu") show_menu ;;
    "help"|*) show_help ;;
  esac
fi

exit 0
