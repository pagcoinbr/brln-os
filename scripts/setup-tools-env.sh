#!/bin/bash

# BRLN-Tools - Dependency Management
# Environment setup for BRLN Tools (password manager and helpers)

# Import common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Configure dynamic paths
configure_brln_paths
# Now we have: VENV_DIR_TOOLS, REQUIREMENTS_FILE_TOOLS, etc. set dynamically
TOOLS_VENV_DIR="$VENV_DIR_TOOLS"
REQUIREMENTS_FILE="$REQUIREMENTS_FILE_TOOLS"

setup_tools_environment() {
  echo "Setting up BRLN-Tools environment..."
  
  # Create virtual environment directory
  mkdir -p "$(dirname "$TOOLS_VENV_DIR")"
  
  # Create virtual environment if it doesn't exist
  if [[ ! -d "$TOOLS_VENV_DIR" ]]; then
    echo "Creating virtual environment for BRLN-Tools..."
    python3 -m venv "$TOOLS_VENV_DIR"
  fi
  
  # Activate virtual environment
  source "$TOOLS_VENV_DIR/bin/activate"
  
  # Upgrade pip
  pip install --upgrade pip
  
  # Install requirements
  if [[ -f "$REQUIREMENTS_FILE" ]]; then
    echo "Installing BRLN-Tools dependencies..."
    pip install -r "$REQUIREMENTS_FILE"
  else
    echo "Requirements file not found: $REQUIREMENTS_FILE"
    # Install essential dependencies
    pip install cryptography>=41.0.0
  fi
  
  echo "BRLN-Tools environment setup complete!"
}

# Check if running directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  setup_tools_environment
fi
