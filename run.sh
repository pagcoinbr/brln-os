#!/bin/bash
branch=main
git_user=pagcoinbr
# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m' # Sem cor

INSTALL_DIR="/home/admin/brlnfullauto"

cp -r ~/brln-os  ${INSTALL_DIR}

echo -e "${BLUE}Criando usuário administrador/admin.${NC}"
sleep 1

dir_check () {
  # Verifica se o diretório /home/admin existe
if [[ -d "/home/admin" ]]; then
  # Verifica se o dono do diretório é o usuário 'admin'
  owner=$(stat -c '%U' /home/admin)

  if [[ "$owner" != "admin" ]]; then
    echo "⚠️ O diretório /home/admin existe, mas pertence a $owner. Corrigindo..."
    
    # Encerra todos os processos do usuário admin (precaução, caso haja)
    pkill -u admin 2>/dev/null

    # Remove com segurança
    sudo rm -rf /home/admin

    # Recria o diretório
    sudo mkdir -p /home/admin
    sudo chown admin:admin /home/admin
    sudo chmod 755 /home/admin
  fi
else
  echo
  sudo mkdir -p /home/admin
  sudo chown admin:admin /home/admin
  sudo chmod 755 /home/admin
  echo
fi
  cp -r ~/brln-os  ${INSTALL_DIR}
}

main_call () {
# Identifica e cria o usuário/grupo admin
atual_user=$(whoami)
if [[ $atual_user = "admin" ]]; then
  dir_check
  sudo -u admin bash "$INSTALL_DIR/brunel.sh"
else
  if id "admin" &>/dev/null; then
  sudo -u admin bash "$INSTALL_DIR/brunel.sh"
  exit 0
  fi
fi
  sudo groupadd admin >> /dev/null 2>&1
# Garante que o usuário 'admin' existe
if id "admin" &>/dev/null; then
  sudo passwd admin
  dir_check
  sudo -u admin bash "$INSTALL_DIR/brunel.sh"
  exit 0
else
  sudo adduser --gecos "" --ingroup admin admin
  dir_check
  sudo -u admin bash "$INSTALL_DIR/brunel.sh"
  exit 0
fi
}

main_call
exit 0
