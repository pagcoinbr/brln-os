#!/bin/bash
branch=teste_v0.9
git_user=pagcoinbr
# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # Sem cor

INSTALL_DIR="/home/admin/brlnfullauto"

echo -e "${BLUE}Iniciando instalação do BRLN FullAuto...${NC}"
sleep 1

brln_check () {
  if [[ -d "$INSTALL_DIR" ]]; then
    echo -e "${YELLOW}Digite a senha do usuário admin para continuar...${NC}"
  else
    sudo -u admin git clone -q https://github.com/$git_user/brlnfullauto.git "$INSTALL_DIR" >> /dev/null 2>&1
    sudo chown -R admin:admin "$INSTALL_DIR"
    sleep 2
    sudo -u admin git -C "$INSTALL_DIR" switch $branch > /dev/null
  fi

  sudo usermod -aG sudo,adm,cdrom,dip,plugdev,lxd admin
  sudo chmod +x "$INSTALL_DIR/brlnfullauto.sh"
  sudo -u admin bash "$INSTALL_DIR/brlnfullauto.sh"
  exit 0
}

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
  else
    echo 
  fi
else
  echo
  sudo mkdir -p /home/admin
  sudo chown admin:admin /home/admin
  sudo chmod 755 /home/admin
  echo
fi
}

main_call () {
# Identifica e cria o usuário/grupo admin
atual_user=$(whoami)
if [[ $atual_user = "admin" ]]; then
  echo -e "${GREEN} Você já está logado como admin! ${NC}"
  dir_check
  brln_check
else
  if id "admin" &>/dev/null; then
  sudo -u admin bash "$INSTALL_DIR/brlnfullauto.sh"
  exit 0
  fi
fi
  sudo groupadd admin >> /dev/null 2>&1
# Garante que o usuário 'admin' existe
if id "admin" &>/dev/null; then
  sudo passwd admin
  dir_check
  brln_check
  exit 0
else
  sudo adduser --gecos "" --ingroup admin admin
  dir_check
  brln_check
  exit 0
fi
}

main_call
exit 0