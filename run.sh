#!/bin/bash

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # Sem cor

INSTALL_DIR="/home/admin/brlnfullauto"

echo -e "${GREEN}Iniciando instalação do BRLN FullAuto...${NC}"
sleep 1

dir_check () {
  if [[ -d "$INSTALL_DIR" ]]; then
    echo -e "${GREEN}Diretório brlnfullauto já presente.${NC}"
  else
    echo -e "${RED}Diretório brlnfullauto não encontrado, baixando...${NC}"
    git clone https://github.com/REDACTED_USERbr/brlnfullauto.git "$INSTALL_DIR" >> /dev/null 2>&1
    sleep 2
    cd "$INSTALL_DIR"
    git checkout v0.8-beta >> /dev/null 2>&1
  fi
  sudo usermod -aG sudo,adm,cdrom,dip,plugdev,lxd admin
  chmod +x "$INSTALL_DIR/brlnfullauto.sh"
  sudo -u admin bash -c /home/user/brlnfullauto.sh
  exit 0
}

# Identifica e cria o usuário/grupo admin
atual_user=$(whoami)
if [[ $atual_user = "admin" ]]; then
  echo -e "${GREEN} Você já está logado como admin! ${NC}"
  dir_check
else
  echo -e "${RED} Você não está logado como admin! ${NC}"
  echo -e "${YELLOW} Você precisa estar logado como admin para prosseguir com a instalação do lnd! ${NC}"
fi
read -p "Você deseja criar um usuário admin? (yes/no): " create_user
if [[ $create_user == "yes" ]]; then
# Garante que o grupo 'admin' existe
if getent group admin > /dev/null; then
    echo "✅ Grupo 'admin' já existe."
else
    echo "➕ Criando grupo 'admin'..."
    sudo groupadd admin
fi

# Garante que o usuário 'admin' existe
if id "admin" &>/dev/null; then
  echo "✅ Usuário 'admin' já existe."
  sudo passwd admin
  dir_check
else
  echo "➕ Criando usuário 'admin' e adicionando ao grupo 'admin'..."
  sudo adduser --gecos "" --ingroup admin admin
  dir_check
fi
elif [[ $create_user == "no" ]]; then
  echo -e "${RED} Você escolheu não criar um usuário admin! ${NC}"
  echo -e "${YELLOW} Você precisa estar logado como admin para prosseguir com a instalação do lnd! ${NC}"
  exit 1
fi
