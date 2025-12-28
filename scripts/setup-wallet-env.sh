#!/bin/bash

# Wallet Integration Scripts - Dependency Management
# Environment setup for wallet restoration and integration tools

WALLET_VENV_DIR="/root/brln-os-envs/wallet-tools"

setup_wallet_environment() {
  echo "Setting up Wallet Tools environment..."
  
  # Create virtual environment directory
  mkdir -p "$(dirname "$WALLET_VENV_DIR")"
  
  # Create virtual environment if it doesn't exist
  if [[ ! -d "$WALLET_VENV_DIR" ]]; then
    echo "Creating virtual environment for Wallet Tools..."
    python3 -m venv "$WALLET_VENV_DIR"
  fi
  
  # Activate virtual environment
  source "$WALLET_VENV_DIR/bin/activate"
  
  # Upgrade pip
  pip install --upgrade pip
  
  # Install wallet-specific dependencies
  echo "Installing Wallet Tools dependencies..."
  pip install cryptography>=41.0.7
  pip install mnemonic>=0.21
  pip install bip32>=5.0.0
  pip install base58>=2.1.1
  pip install ecdsa>=0.19.0
  
  echo "Wallet Tools environment setup complete!"
}

# Check if running directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  setup_wallet_environment
fi