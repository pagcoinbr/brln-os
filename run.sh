#!/bin/bash

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # Sem cor

INSTALL_DIR="/home/admin/brlnfullauto"

# Cria o diretório home/admin se não existir
mkdir -p /home/admin

# Verifica se o repositório já existe
if [[ -d "$INSTALL_DIR" ]]; then
  echo -e "${GREEN}Diretório brlnfullauto já presente.${NC}"
else
  echo -e "${RED}Diretório brlnfullauto não encontrado, baixando...${NC}"
  git clone https://github.com/pagcoinbr/brlnfullauto.git "$INSTALL_DIR" >> "$INSTALL_DIR/install.log" 2>&1
  cd "$INSTALL_DIR"
  touch 
  git stash >> install.log 2>&1
  git checkout v0.8-beta >> install.log 2>&1
fi

chmod +x "$INSTALL_DIR/brlnfullauto.sh"
"$INSTALL_DIR/brlnfullauto.sh"
