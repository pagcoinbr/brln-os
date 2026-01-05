#!/bin/bash

# BRLN-Tools - Dependency Management
# Environment setup for BRLN Tools (Telegram bots, etc.)

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
    pip install pyTelegramBotAPI>=4.14.1 requests>=2.25.1 schedule>=1.2.1 telebot>=0.0.5
  fi
  
  echo "BRLN-Tools environment setup complete!"
}

# Check if running directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  setup_tools_environment
fi

# ============================================================================
# RESUMO DO SCRIPT SETUP-TOOLS-ENV.SH
# ============================================================================
#
# DESCRIÇÃO:
# - Cria/atualiza ambiente virtual para as ferramentas BRLN-Tools (bots Telegram,
#   utilitários) e instala dependências via requirements.txt.
#
# FUNCIONALIDADE PRINCIPAL:
# - setup_tools_environment(): Cria venv, ativa-o, instala pacotes listados em
#   REQUIREMENTS_FILE_TOOLS ou um conjunto mínimo de dependências essenciais.
#
# USO:
# - Executar diretamente para configurar o ambiente de ferramentas do sistema
#   (por exemplo, antes de rodar bots e scripts auxiliares).
#
# ============================================================================
