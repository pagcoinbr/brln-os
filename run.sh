#!/bin/bash

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # Sem cor

INSTALL_DIR="/home/admin/brlnfullauto"

echo -e "${GREEN}Iniciando instalação do BRLN FullAuto...${NC}"
sleep 1

# Cria o diretório home/admin se não existir
mkdir -p /home/admin

# Verifica se o repositório já existe
if [[ -d "$INSTALL_DIR" ]]; then
  echo -e "${GREEN}Diretório brlnfullauto já presente.${NC}"
else
  echo -e "${RED}Diretório brlnfullauto não encontrado, baixando...${NC}"
  git clone https://github.com/REDACTED_USERbr/brlnfullauto.git "$INSTALL_DIR" >> /dev/null 2>&1
  sleep 2
  cd "$INSTALL_DIR"
  touch install.log
  git stash /dev/null 2>&1
  git checkout v0.8-beta >> /dev/null 2>&1
fi

chmod +x "$INSTALL_DIR/brlnfullauto.sh"
"$INSTALL_DIR/brlnfullauto.sh"
