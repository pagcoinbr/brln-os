#!/bin/bash

# API BRLN-OS - Dependency Management
# Environment setup for BRLN-OS API v1

# Import common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Configure dynamic paths
configure_brln_paths
# Now we have: VENV_DIR_API, REQUIREMENTS_FILE_API, etc. set dynamically
API_VENV_DIR="$VENV_DIR_API"
REQUIREMENTS_FILE="$REQUIREMENTS_FILE_API"

setup_api_environment() {
  echo "Setting up BRLN-OS API environment..."
  
  # Use dedicated API venv location for the brln-api user
  API_VENV_DIR="/home/brln-api/venv"
  
  # Create virtual environment directory with proper permissions
  sudo mkdir -p "$(dirname "$API_VENV_DIR")"
  
  # Create virtual environment if it doesn't exist
  if [[ ! -d "$API_VENV_DIR" ]]; then
    echo "Creating virtual environment for API..."
    sudo python3 -m venv "$API_VENV_DIR"
    sudo chown -R brln-api:brln-api "$API_VENV_DIR"
  fi
  
  # Activate virtual environment
  source "$API_VENV_DIR/bin/activate"
  
  # Upgrade pip
  pip install --upgrade pip
  
  # Install requirements
  if [[ -f "$REQUIREMENTS_FILE" ]]; then
    echo "Installing API dependencies..."
    pip install -r "$REQUIREMENTS_FILE"
  else
    echo "Requirements file not found: $REQUIREMENTS_FILE"
    # Install essential dependencies
    pip install Flask==3.0.0 flask-cors==4.0.0 psutil==5.9.6 pydbus==0.6.0 requests==2.31.0
    pip install grpcio==1.59.0 grpcio-tools==1.59.0 protobuf==4.24.4
    pip install mnemonic==0.21 bip32==5.0.0 cryptography==41.0.7 base58==2.1.1 ecdsa==0.19.0
    pip install eth-hash[pycryptodome]==0.5.2 pycryptodome==3.20.0
  fi
  
  # Fix ownership after all pip operations
  sudo chown -R brln-api:brln-api "$API_VENV_DIR"
  
  echo "API environment setup complete!"
}

# Check if running directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  setup_api_environment
fi